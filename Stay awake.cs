// Stay awake - keeps Windows awake for a set or unlimited time, with the screen kept on or turned off.
// Build: build.cmd  (uses the C# compiler that ships with Windows / .NET Framework 4.x)

using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace StayAwake
{
    internal static class Native
    {
        [Flags]
        public enum ExecutionState : uint
        {
            SystemRequired = 0x00000001,
            DisplayRequired = 0x00000002,
            Continuous = 0x80000000
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern ExecutionState SetThreadExecutionState(ExecutionState esFlags);

        [DllImport("user32.dll")]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool DestroyIcon(IntPtr handle);

        public const uint WM_SYSCOMMAND = 0x0112;
        public const int SC_MONITORPOWER = 0xF170;
        public const int MONITOR_OFF = 2;
    }

    public class MainForm : Form
    {
        private readonly RadioButton rbUnlimited;
        private readonly RadioButton rbDuration;
        private readonly NumericUpDown nudHours;
        private readonly NumericUpDown nudMinutes;
        private readonly RadioButton rbScreenTimeout;
        private readonly RadioButton rbScreenOffNow;
        private readonly RadioButton rbScreenOn;
        private readonly Button btnStartStop;
        private readonly Label lblStatus;
        private readonly Timer tick;
        private readonly NotifyIcon tray;
        private readonly ToolStripMenuItem trayStartStop;
        private readonly Icon iconIdle;
        private readonly Icon iconActive;

        private bool active;
        private DateTime? endTime;
        private bool reallyExit;

        public MainForm()
        {
            Text = "Stay awake";
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(340, 326);
            Font = new Font("Segoe UI", 9.5f);

            iconIdle = MakeIcon(Color.FromArgb(120, 120, 120));
            iconActive = MakeIcon(Color.FromArgb(0, 150, 90));
            Icon = iconIdle;

            // --- Duration ---
            var grpTime = new GroupBox { Text = "Keep awake", Location = new Point(12, 10), Size = new Size(316, 92) };
            rbUnlimited = new RadioButton { Text = "Unlimited (until stopped)", Location = new Point(12, 22), AutoSize = true, Checked = true };
            rbDuration = new RadioButton { Text = "For", Location = new Point(12, 54), AutoSize = true };
            nudHours = new NumericUpDown { Location = new Point(62, 52), Width = 55, Minimum = 0, Maximum = 999, Value = 1 };
            var lblH = new Label { Text = "h", Location = new Point(120, 55), AutoSize = true };
            nudMinutes = new NumericUpDown { Location = new Point(140, 52), Width = 55, Minimum = 0, Maximum = 59, Value = 0 };
            var lblM = new Label { Text = "min", Location = new Point(198, 55), AutoSize = true };
            grpTime.Controls.AddRange(new Control[] { rbUnlimited, rbDuration, nudHours, lblH, nudMinutes, lblM });
            rbDuration.CheckedChanged += delegate { UpdateUi(); };

            // --- Screen ---
            var grpScreen = new GroupBox { Text = "Screen", Location = new Point(12, 108), Size = new Size(316, 104) };
            rbScreenTimeout = new RadioButton { Text = "Turn off after normal time-out", Location = new Point(12, 22), AutoSize = true, Checked = true };
            rbScreenOffNow = new RadioButton { Text = "Turn off now", Location = new Point(12, 48), AutoSize = true };
            rbScreenOn = new RadioButton { Text = "Keep screen on", Location = new Point(12, 74), AutoSize = true };
            grpScreen.Controls.AddRange(new Control[] { rbScreenTimeout, rbScreenOffNow, rbScreenOn });

            // --- Start/Stop + status ---
            btnStartStop = new Button { Text = "Start", Location = new Point(12, 222), Size = new Size(316, 34) };
            btnStartStop.Click += delegate { if (active) StopAwake(); else StartAwake(); };
            lblStatus = new Label { Location = new Point(12, 266), Size = new Size(316, 50) };

            Controls.AddRange(new Control[] { grpTime, grpScreen, btnStartStop, lblStatus });

            tick = new Timer { Interval = 1000 };
            tick.Tick += OnTick;

            // --- Tray ---
            var menu = new ContextMenuStrip();
            trayStartStop = new ToolStripMenuItem("Start", null, delegate { if (active) StopAwake(); else StartAwake(); });
            menu.Items.Add(new ToolStripMenuItem("Show window", null, delegate { ShowFromTray(); }));
            menu.Items.Add(trayStartStop);
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(new ToolStripMenuItem("Exit", null, delegate { reallyExit = true; Close(); }));

            tray = new NotifyIcon { Icon = iconIdle, Text = "Stay awake - idle", Visible = true, ContextMenuStrip = menu };
            tray.DoubleClick += delegate { ShowFromTray(); };

            Resize += delegate { if (WindowState == FormWindowState.Minimized) Hide(); };

            UpdateUi();
        }

        private void StartAwake()
        {
            if (rbDuration.Checked)
            {
                var span = new TimeSpan((int)nudHours.Value, (int)nudMinutes.Value, 0);
                if (span.TotalMinutes < 1)
                {
                    MessageBox.Show(this, "Please choose a duration of at least 1 minute.", "Stay awake",
                        MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                endTime = DateTime.Now + span;
            }
            else
            {
                endTime = null;
            }

            active = true;
            ApplyExecutionState();
            tick.Start();
            UpdateUi();

            if (rbScreenOffNow.Checked) TurnScreenOff();
        }

        private void StopAwake()
        {
            active = false;
            endTime = null;
            tick.Stop();
            Native.SetThreadExecutionState(Native.ExecutionState.Continuous); // release
            UpdateUi();
        }

        private void ApplyExecutionState()
        {
            var flags = Native.ExecutionState.Continuous | Native.ExecutionState.SystemRequired;
            if (rbScreenOn.Checked) flags |= Native.ExecutionState.DisplayRequired;
            Native.SetThreadExecutionState(flags);
        }

        private void OnTick(object sender, EventArgs e)
        {
            if (!active) return;
            if (endTime.HasValue && DateTime.Now >= endTime.Value)
            {
                StopAwake();
                tray.ShowBalloonTip(3000, "Stay awake", "Time is up - normal power settings restored.", ToolTipIcon.Info);
                return;
            }
            ApplyExecutionState();
            UpdateStatusText();
        }

        private void UpdateUi()
        {
            btnStartStop.Text = active ? "Stop" : "Start";
            trayStartStop.Text = active ? "Stop" : "Start";
            rbUnlimited.Enabled = rbDuration.Enabled = !active;
            nudHours.Enabled = nudMinutes.Enabled = rbDuration.Checked && !active;
            rbScreenTimeout.Enabled = rbScreenOffNow.Enabled = rbScreenOn.Enabled = !active;
            Icon = tray.Icon = active ? iconActive : iconIdle;
            UpdateStatusText();
        }

        private void UpdateStatusText()
        {
            string text;
            if (!active)
            {
                text = "Idle - normal power settings apply.";
                lblStatus.ForeColor = Color.DimGray;
            }
            else
            {
                string what = rbScreenOn.Checked ? "PC and screen kept on"
                    : rbScreenOffNow.Checked ? "PC kept awake, screen turned off"
                    : "PC kept awake, screen follows normal time-out";
                if (endTime.HasValue)
                {
                    var left = endTime.Value - DateTime.Now;
                    if (left < TimeSpan.Zero) left = TimeSpan.Zero;
                    text = string.Format("{0}.\nTime left: {1:00}:{2:00}:{3:00}  (until {4:t})",
                        what, (int)left.TotalHours, left.Minutes, left.Seconds, endTime.Value);
                }
                else
                {
                    text = what + ".\nUnlimited - until you press Stop.";
                }
                lblStatus.ForeColor = Color.FromArgb(0, 120, 70);
            }
            lblStatus.Text = text;

            string tip = active
                ? (endTime.HasValue ? "Stay awake - active until " + endTime.Value.ToString("t") : "Stay awake - active (unlimited)")
                : "Stay awake - idle";
            tray.Text = tip.Length > 63 ? tip.Substring(0, 63) : tip;
        }

        private void TurnScreenOff()
        {
            // Short delay so the mouse-up from clicking Start doesn't immediately wake the screen.
            var t = new Timer { Interval = 700 };
            t.Tick += delegate
            {
                t.Stop();
                t.Dispose();
                Native.SendMessage(Handle, Native.WM_SYSCOMMAND, (IntPtr)Native.SC_MONITORPOWER, (IntPtr)Native.MONITOR_OFF);
            };
            t.Start();
        }

        private void ShowFromTray()
        {
            Show();
            WindowState = FormWindowState.Normal;
            Activate();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            // Closing the window while active keeps running in the tray.
            if (!reallyExit && active && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                Hide();
                tray.ShowBalloonTip(2500, "Stay awake", "Still running in the tray. Right-click the icon to exit.", ToolTipIcon.Info);
                return;
            }
            Native.SetThreadExecutionState(Native.ExecutionState.Continuous);
            tray.Visible = false;
            tray.Dispose();
            base.OnFormClosing(e);
        }

        private static Icon MakeIcon(Color color)
        {
            using (var bmp = new Bitmap(32, 32))
            {
                using (var g = Graphics.FromImage(bmp))
                {
                    g.SmoothingMode = SmoothingMode.AntiAlias;
                    g.Clear(Color.Transparent);
                    using (var b = new SolidBrush(color)) g.FillEllipse(b, 1, 1, 30, 30);
                    using (var w = new SolidBrush(Color.White)) g.FillEllipse(w, 6, 10, 20, 12);
                    using (var p = new SolidBrush(color)) g.FillEllipse(p, 11, 11, 10, 10);
                }
                IntPtr h = bmp.GetHicon();
                var icon = (Icon)Icon.FromHandle(h).Clone();
                Native.DestroyIcon(h);
                return icon;
            }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
