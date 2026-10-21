using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace PclPatchUi
{
    /// <summary>通用绘图工具</summary>
    internal static class Ux
    {
        public static GraphicsPath RoundRect(Rectangle r, int radius)
        {
            var p = new GraphicsPath();
            int d = radius * 2;
            if (d <= 0 || r.Width <= 0 || r.Height <= 0) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d - 1, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d - 1, r.Bottom - d - 1, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d - 1, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void SoftShadow(Graphics g, Rectangle rect, int radius)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            for (int i = 6; i >= 1; i--)
            {
                var r = rect;
                r.Inflate(i, i);
                r.Offset(0, i - 1);
                int alpha = 4 + (6 - i) * 2;
                using (var p = RoundRect(r, radius + i))
                using (var b = new SolidBrush(Color.FromArgb(alpha, 35, 45, 60)))
                {
                    g.FillPath(b, p);
                }
            }
        }
    }

    /// <summary>圆角卡片：自绘圆角 + 柔和投影 + 淡金卷草纹</summary>
    public class RoundPanel : Panel
    {
        public int CornerRadius { get; set; }
        public Color BorderColor { get; set; }
        public Color FillColor { get; set; }
        public bool DrawFiligree { get; set; }
        public bool DrawBorder { get; set; }
        public int ShadowMargin { get; set; }

        public RoundPanel()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            CornerRadius = 14;
            BorderColor = Color.FromArgb(227, 230, 234);
            FillColor = Color.White;
            DrawFiligree = false;
            DrawBorder = true;
            ShadowMargin = 8;
        }

        private Rectangle CardRect()
        {
            var r = ClientRectangle;
            r.Inflate(-ShadowMargin, -ShadowMargin);
            return r;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.FromArgb(247, 248, 250);
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width <= ShadowMargin * 2 || Height <= ShadowMargin * 2) return;
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;

            var card = CardRect();
            Ux.SoftShadow(g, card, CornerRadius);

            using (var path = Ux.RoundRect(card, CornerRadius))
            {
                using (var bg = new SolidBrush(FillColor)) g.FillPath(bg, path);
                if (DrawFiligree)
                {
                    var old = g.Clip;
                    g.SetClip(path, CombineMode.Intersect);
                    Filigree.Draw(g, card);
                    g.Clip = old;
                }
                if (DrawBorder)
                {
                    using (var pen = new Pen(BorderColor, 1f)) g.DrawPath(pen, path);
                }
            }
        }
    }

    /// <summary>圆角输入框</summary>
    public class RoundTextBox : Panel
    {
        public TextBox Inner { get; private set; }
        public int CornerRadius { get; set; }

        public RoundTextBox()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;

            Inner = new TextBox();
            Inner.BorderStyle = BorderStyle.None;
            Inner.BackColor = Color.FromArgb(251, 251, 252);
            Inner.Font = new Font("Microsoft YaHei UI", 9.5f);
            Controls.Add(Inner);
            Padding = new Padding(13, 0, 13, 0);
            Height = 42;
            CornerRadius = 8;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.White;
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Inner != null)
            {
                Inner.Left = Padding.Left;
                Inner.Width = Width - Padding.Left - Padding.Right;
                Inner.Top = (Height - Inner.Height) / 2;
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var p = Ux.RoundRect(new Rectangle(0, 0, Width - 1, Height - 1), CornerRadius))
            {
                using (var bg = new SolidBrush(Color.FromArgb(251, 251, 252))) g.FillPath(bg, p);
                using (var pen = new Pen(Color.FromArgb(227, 230, 234), 1f)) g.DrawPath(pen, p);
            }
        }
    }

    /// <summary>圆角按钮</summary>
    public class RoundButton : Button
    {
        public int CornerRadius { get; set; }

        public RoundButton()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            CornerRadius = 8;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.FromArgb(247, 248, 250);
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            using (var p = Ux.RoundRect(new Rectangle(0, 0, Width - 1, Height - 1), CornerRadius))
            {
                using (var bg = new SolidBrush(BackColor)) g.FillPath(bg, p);
                if (FlatAppearance.BorderSize > 0)
                {
                    using (var pen = new Pen(FlatAppearance.BorderColor, 1f)) g.DrawPath(pen, p);
                }
            }

            var flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter |
                        TextFormatFlags.NoPadding | TextFormatFlags.SingleLine;
            TextRenderer.DrawText(g, Text, Font, ClientRectangle, ForeColor, flags);
        }
    }

    /// <summary>圆角日志区</summary>
    public class RoundRichText : Panel
    {
        public RichTextBox Inner { get; private set; }
        public int CornerRadius { get; set; }

        public RoundRichText()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;

            Inner = new RichTextBox();
            Inner.BorderStyle = BorderStyle.None;
            Inner.BackColor = Color.White;
            Inner.ReadOnly = true;
            Inner.ScrollBars = RichTextBoxScrollBars.Vertical;
            Inner.DetectUrls = false;
            Controls.Add(Inner);
            Padding = new Padding(16, 12, 16, 12);
            CornerRadius = 10;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.FromArgb(247, 248, 250);
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (Inner != null)
            {
                Inner.Left = Padding.Left;
                Inner.Top = Padding.Top;
                Inner.Width = Width - Padding.Left - Padding.Right;
                Inner.Height = Height - Padding.Top - Padding.Bottom;
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (var p = Ux.RoundRect(new Rectangle(0, 0, Width - 1, Height - 1), CornerRadius))
            {
                using (var bg = new SolidBrush(Color.White)) g.FillPath(bg, p);
                using (var pen = new Pen(Color.FromArgb(238, 240, 243), 1f)) g.DrawPath(pen, p);
            }
        }
    }

    /// <summary>自绘单选行：Panel 派生，完全掌控绘制，避免基类文字叠加</summary>
    public class RoundRadio : Panel
    {
        private bool _checked;
        public bool Checked
        {
            get { return _checked; }
            set { if (_checked != value) { _checked = value; Invalidate(); } }
        }

        public string MainText { get; set; }
        public string HintText { get; set; }
        public Color HintColor { get; set; }
        public Color AccentColor { get; set; }
        public Color NormalBorderColor { get; set; }
        public int CircleSize { get; set; }
        public Font MainFont { get; set; }
        public Font HintFont { get; set; }

        public event EventHandler CheckedChanged;

        public RoundRadio()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            CircleSize = 17;
            AccentColor = Color.FromArgb(59, 130, 246);
            NormalBorderColor = Color.FromArgb(211, 215, 221);
            HintColor = Color.FromArgb(154, 163, 175);
            MainText = string.Empty;
            HintText = string.Empty;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.White;
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int cy = Height / 2;
            var circle = new Rectangle(0, cy - CircleSize / 2, CircleSize, CircleSize);
            using (var pen = new Pen(Checked ? AccentColor : NormalBorderColor, 1.8f))
                g.DrawEllipse(pen, circle);
            if (Checked)
            {
                int inset = 4;
                using (var br = new SolidBrush(AccentColor))
                    g.FillEllipse(br, circle.X + inset, circle.Y + inset,
                        CircleSize - inset * 2, CircleSize - inset * 2);
            }

            var mainFont = MainFont ?? Font;
            var hintFont = HintFont ?? new Font(mainFont.FontFamily, Math.Max(7.5f, mainFont.Size - 1f));

            int textLeft = CircleSize + 10;
            int textHeight = TextRenderer.MeasureText("国", mainFont).Height;
            int textTop = cy - textHeight / 2;

            var mainSize = TextRenderer.MeasureText(MainText ?? string.Empty, mainFont,
                new Size(int.MaxValue, int.MaxValue), TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);

            if (!string.IsNullOrEmpty(MainText))
            {
                TextRenderer.DrawText(g, MainText, mainFont,
                    new Rectangle(textLeft, textTop, mainSize.Width + 2, textHeight),
                    ForeColor, TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
            }

            if (!string.IsNullOrEmpty(HintText))
            {
                int hintLeft = textLeft + mainSize.Width + 14;
                int hintWidth = Math.Max(10, Width - hintLeft);
                TextRenderer.DrawText(g, "— " + HintText, hintFont,
                    new Rectangle(hintLeft, textTop, hintWidth, textHeight),
                    HintColor, TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
            }

            if (!ReferenceEquals(hintFont, MainFont) && HintFont == null) hintFont.Dispose();
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            if (!Checked)
            {
                Checked = true;
                if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
            }
        }
    }

    /// <summary>自绘复选行</summary>
    public class RoundCheck : Panel
    {
        private bool _checked;
        public bool Checked
        {
            get { return _checked; }
            set { if (_checked != value) { _checked = value; Invalidate(); } }
        }

        public Color AccentColor { get; set; }
        public Color BoxBorderColor { get; set; }
        public int BoxSize { get; set; }

        public RoundCheck()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw |
                     ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            BoxSize = 16;
            AccentColor = Color.FromArgb(59, 130, 246);
            BoxBorderColor = Color.FromArgb(207, 212, 218);
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            var c = Parent != null ? Parent.BackColor : Color.White;
            using (var b = new SolidBrush(c)) e.Graphics.FillRectangle(b, ClientRectangle);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            int cy = Height / 2;
            var box = new Rectangle(0, cy - BoxSize / 2, BoxSize, BoxSize);
            using (var p = Ux.RoundRect(box, 4))
            {
                using (var bg = new SolidBrush(Color.FromArgb(251, 251, 252))) g.FillPath(bg, p);
                using (var pen = new Pen(Checked ? AccentColor : BoxBorderColor, 1.4f)) g.DrawPath(pen, p);
            }
            if (Checked)
            {
                using (var pen = new Pen(AccentColor, 2f))
                {
                    pen.StartCap = LineCap.Round;
                    pen.EndCap = LineCap.Round;
                    g.DrawLines(pen, new[]
                    {
                        new PointF(box.X + 3.5f, box.Y + 8.2f),
                        new PointF(box.X + 6.6f, box.Y + 11.4f),
                        new PointF(box.X + 12.4f, box.Y + 4.6f)
                    });
                }
            }

            int textLeft = BoxSize + 10;
            int textHeight = TextRenderer.MeasureText("国", Font).Height;
            TextRenderer.DrawText(g, Text ?? string.Empty, Font,
                new Rectangle(textLeft, cy - textHeight / 2, Math.Max(10, Width - textLeft), textHeight),
                ForeColor, TextFormatFlags.Left | TextFormatFlags.NoPadding | TextFormatFlags.SingleLine);
        }

        protected override void OnClick(EventArgs e)
        {
            base.OnClick(e);
            Checked = !Checked;
        }
    }

    /// <summary>淡金卷草纹</summary>
    public static class Filigree
    {
        public static void Draw(Graphics g, Rectangle card)
        {
            var line1 = Color.FromArgb(26, 184, 137, 76);
            var line2 = Color.FromArgb(26, 227, 198, 143);
            var leafFill = Color.FromArgb(10, 184, 137, 76);
            var leafStroke = Color.FromArgb(20, 184, 137, 76);
            var flowerColor = Color.FromArgb(14, 184, 137, 76);

            const float scale = 0.78f;
            float artW = 220f * scale;
            float artH = 200f * scale;
            float offsetX = card.Right - artW - 26f;
            float offsetY = card.Bottom - artH - 34f;

            var state = g.Save();
            g.TranslateTransform(offsetX, offsetY);
            g.ScaleTransform(scale, scale);
            g.SmoothingMode = SmoothingMode.AntiAlias;

            using (var grad = new LinearGradientBrush(
                new Point(0, 220), new Point(220, 0), line1, line2))
            using (var pen = new Pen(grad, 2.0f))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                pen.LineJoin = LineJoin.Round;

                Bez(g, pen, 24,196,  44,176,  58,168,  78,154);
                Bez(g, pen, 78,154, 104,136, 126,112, 146,88);
                Bez(g, pen, 146,88, 162,68,  172,52,  180,36);
                Bez(g, pen, 180,36, 188,20,  204,24,  202,38);
                Bez(g, pen, 202,38, 200,50,  188,52,  184,42);
                Bez(g, pen, 78,154,  66,168,  50,170,  46,160);
                Bez(g, pen, 46,160,  42,150,  54,142,  62,148);
                Bez(g, pen, 146,88, 158,96,  172,96,  176,86);
                Bez(g, pen, 176,86, 179,78,  170,72,  164,78);
                Bez(g, pen, 126,112, 128,132, 120,148, 108,152);
                Bez(g, pen, 108,152, 98,155,  92,146,  98,140);
                Bez(g, pen, 44,176,  32,186,  20,182,  20,172);
                Bez(g, pen, 20,172,  20,164,  30,162,  34,168);
            }

            using (var thinGrad = new LinearGradientBrush(
                new Point(0, 160), new Point(160, 30), line1, line2))
            using (var thin = new Pen(thinGrad, 1.3f))
            {
                thin.StartCap = LineCap.Round;
                thin.EndCap = LineCap.Round;
                Bez(g, thin, 110,120, 108,96,  112,72,  120,52);
                Bez(g, thin, 62,150,  56,132,  58,114,  66,98);
            }

            using (var lf = new SolidBrush(leafFill))
            using (var lp = new Pen(leafStroke, 1.0f))
            {
                Leaf(g, lf, lp,  78,154,  66,158,  58,152,  60,142,  70,142,  76,148);
                Leaf(g, lf, lp, 104,136, 108,122, 120,116, 128,122, 122,132, 112,138);
                Leaf(g, lf, lp, 146,88,  144,74,  152,64,  162,66,  158,78,  150,86);
                Leaf(g, lf, lp, 162,68,  172,74,  176,86,  168,92,  160,84,  158,74);
                Leaf(g, lf, lp, 126,112, 114,118, 102,116, 100,106, 110,102, 120,106);
                Leaf(g, lf, lp,  58,168,  52,180,  42,184,  36,176,  42,166,  52,164);
                Leaf(g, lf, lp, 120,52,  116,38,  124,28,  134,30,  130,42,  124,50);
                Leaf(g, lf, lp,  66,98,   62,86,   68,76,   78,78,   76,90,   70,96);
            }

            using (var fb = new SolidBrush(flowerColor))
            using (var fp = new Pen(leafStroke, 0.9f))
            {
                Flower(g, fb, fp,  88,128, 0.50f);
                Flower(g, fb, fp, 170, 62, 0.42f);
                Flower(g, fb, fp, 138, 46, 0.44f);
            }

            g.Restore(state);
        }

        private static void Bez(Graphics g, Pen pen,
            float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4)
        {
            g.DrawBezier(pen, new PointF(x1, y1), new PointF(x2, y2), new PointF(x3, y3), new PointF(x4, y4));
        }

        private static void Leaf(Graphics g, Brush b, Pen outline, params float[] pts)
        {
            var arr = new PointF[pts.Length / 2];
            for (int i = 0; i < arr.Length; i++) arr[i] = new PointF(pts[i * 2], pts[i * 2 + 1]);
            using (var p = new GraphicsPath())
            {
                p.AddClosedCurve(arr, 0.4f);
                g.FillPath(b, p);
                g.DrawPath(outline, p);
            }
        }

        private static void Flower(Graphics g, Brush b, Pen outline, float cx, float cy, float s)
        {
            var st = g.Save();
            g.TranslateTransform(cx, cy);
            g.ScaleTransform(s, s);
            for (int i = 0; i < 3; i++)
            {
                var st3 = g.Save();
                g.RotateTransform(i * 120);
                var petal = new RectangleF(-7, -21, 14, 21);
                g.FillEllipse(b, petal);
                g.DrawEllipse(outline, petal);
                g.Restore(st3);
            }
            g.Restore(st);
        }
    }
}
