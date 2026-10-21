using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace PclPatchUi
{
    /// <summary>圆角面板：自绘圆角背景、边框，可带淡金卷草纹</summary>
    public class RoundPanel : Panel
    {
        public int CornerRadius { get; set; }
        public Color BorderColor { get; set; }
        public Color FillColor { get; set; }
        public bool DrawFiligree { get; set; }
        public bool DrawBorder { get; set; }

        public RoundPanel()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;
            CornerRadius = 14;
            BorderColor = Color.FromArgb(227, 230, 234);
            FillColor = Color.White;
            DrawFiligree = false;
            DrawBorder = true;
        }

        private GraphicsPath BuildPath()
        {
            var p = new GraphicsPath();
            int d = CornerRadius * 2;
            int w = Width, h = Height;
            if (w <= 0 || h <= 0) return p;
            p.AddArc(0, 0, d, d, 180, 90);
            p.AddArc(w - d - 1, 0, d, d, 270, 90);
            p.AddArc(w - d - 1, h - d - 1, d, d, 0, 90);
            p.AddArc(0, h - d - 1, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (Width <= 0 || Height <= 0) return;
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;

            using (var path = BuildPath())
            {
                using (var bg = new SolidBrush(FillColor)) g.FillPath(bg, path);
                if (DrawBorder)
                {
                    using (var pen = new Pen(BorderColor, 1f)) g.DrawPath(pen, path);
                }
                if (DrawFiligree)
                {
                    var old = g.Clip;
                    g.SetClip(path, CombineMode.Intersect);
                    Filigree.Draw(g, Width, Height);
                    g.Clip = old;
                }
            }
        }
    }

    /// <summary>圆角输入框：外层自绘圆角，内部承载无边框的 TextBox</summary>
    public class RoundTextBox : Panel
    {
        public TextBox Inner { get; private set; }
        public int CornerRadius { get; set; }

        public RoundTextBox()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;

            Inner = new TextBox();
            Inner.BorderStyle = BorderStyle.None;
            Inner.BackColor = Color.FromArgb(251, 251, 252);
            Controls.Add(Inner);
            Padding = new Padding(12, 0, 12, 0);
            Height = 40;
            CornerRadius = 8;
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
            int d = CornerRadius * 2;
            using (var p = new GraphicsPath())
            {
                p.AddArc(0, 0, d, d, 180, 90);
                p.AddArc(Width - d - 1, 0, d, d, 270, 90);
                p.AddArc(Width - d - 1, Height - d - 1, d, d, 0, 90);
                p.AddArc(0, Height - d - 1, d, d, 90, 90);
                p.CloseFigure();
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
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            FlatStyle = FlatStyle.Flat;
            FlatAppearance.BorderSize = 0;
            CornerRadius = 8;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            int d = CornerRadius * 2;
            using (var p = new GraphicsPath())
            {
                p.AddArc(0, 0, d, d, 180, 90);
                p.AddArc(Width - d - 1, 0, d, d, 270, 90);
                p.AddArc(Width - d - 1, Height - d - 1, d, d, 0, 90);
                p.AddArc(0, Height - d - 1, d, d, 90, 90);
                p.CloseFigure();
                using (var bg = new SolidBrush(BackColor)) g.FillPath(bg, p);
                if (FlatAppearance.BorderSize > 0)
                {
                    using (var pen = new Pen(FlatAppearance.BorderColor, 1f)) g.DrawPath(pen, p);
                }
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle, ForeColor,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }

    /// <summary>圆角富文本框（日志区）</summary>
    public class RoundRichText : Panel
    {
        public RichTextBox Inner { get; private set; }
        public int CornerRadius { get; set; }

        public RoundRichText()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                     ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;

            Inner = new RichTextBox();
            Inner.BorderStyle = BorderStyle.None;
            Inner.BackColor = Color.White;
            Inner.ReadOnly = true;
            Inner.ScrollBars = RichTextBoxScrollBars.Vertical;
            Controls.Add(Inner);
            Padding = new Padding(16, 12, 16, 12);
            CornerRadius = 10;
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
            int d = CornerRadius * 2;
            using (var p = new GraphicsPath())
            {
                p.AddArc(0, 0, d, d, 180, 90);
                p.AddArc(Width - d - 1, 0, d, d, 270, 90);
                p.AddArc(Width - d - 1, Height - d - 1, d, d, 0, 90);
                p.AddArc(0, Height - d - 1, d, d, 90, 90);
                p.CloseFigure();
                using (var bg = new SolidBrush(Color.White)) g.FillPath(bg, p);
                using (var pen = new Pen(Color.FromArgb(238, 240, 243), 1f)) g.DrawPath(pen, p);
            }
        }
    }

    /// <summary>淡金卷草纹绘制</summary>
    public static class Filigree
    {
        public static void Draw(Graphics g, int panelW, int panelH)
        {
            var gold1 = Color.FromArgb(184, 137, 76);
            var gold2 = Color.FromArgb(227, 198, 143);

            // 图案坐标范围 x:8..199, y:6..168；缩放后约 115x98
            const float scale = 0.60f;
            float artW = 200f * scale;
            float artH = 175f * scale;
            float offsetX = panelW - artW - 16f;
            float offsetY = panelH - artH - 8f;

            var state = g.Save();
            g.TranslateTransform(offsetX, offsetY);
            g.ScaleTransform(scale, scale);
            g.SmoothingMode = SmoothingMode.AntiAlias;

            using (var grad = new LinearGradientBrush(
                new Point(0, 200), new Point(200, 0), gold1, gold2))
            using (var pen = new Pen(grad, 2.2f))
            {
                pen.StartCap = LineCap.Round;
                pen.EndCap = LineCap.Round;
                pen.LineJoin = LineJoin.Round;

                FloatBez(g, pen, 26,168,  8,150,  10,118,  34,106);
                FloatBez(g, pen, 34,106, 62,86,   92,72,  110,64);
                FloatBez(g, pen, 110,64, 132,50, 156,38,  172,22);
                FloatBez(g, pen, 172,22, 182,8,  197,12,  198,25);
                FloatBez(g, pen, 198,25, 199,36, 188,42,  181,36);
                FloatBez(g, pen, 110,64, 108,82, 112,100, 124,110);
                FloatBez(g, pen, 124,110,136,121,154,119, 156,108);
                FloatBez(g, pen, 92,72,   86,56,  90,40,  102,28);
                FloatBez(g, pen, 62,86,   52,70,  50,54,   58,42);
            }

            using (var leaf = new SolidBrush(Color.FromArgb(19, gold1)))
            {
                Leaf(g, leaf, 102,28, 106,14, 118,6, 128,8, 124,22, 114,30);
                Leaf(g, leaf, 58,42, 52,28, 56,14, 66,10, 70,24, 66,38);
                Leaf(g, leaf, 144,48, 152,34, 166,28, 176,32, 168,46, 156,52);
                Leaf(g, leaf, 80,124, 68,118, 62,106, 66,96, 78,102, 84,114);
                Leaf(g, leaf, 132,114, 142,122, 146,134, 141,143, 130,136, 126,124);
            }

            using (var fb = new SolidBrush(Color.FromArgb(22, gold1)))
            {
                Flower(g, fb, 66, 10, 0.60f);
                Flower(g, fb, 181, 36, 0.48f);
            }

            g.Restore(state);
        }

        private static void FloatBez(Graphics g, Pen pen, float x1,float y1,float x2,float y2,float x3,float y3,float x4,float y4)
        {
            g.DrawBezier(pen, new PointF(x1,y1), new PointF(x2,y2), new PointF(x3,y3), new PointF(x4,y4));
        }

        private static void Leaf(Graphics g, Brush b, params float[] pts)
        {
            var arr = new PointF[pts.Length / 2];
            for (int i = 0; i < arr.Length; i++) arr[i] = new PointF(pts[i*2], pts[i*2+1]);
            using (var p = new GraphicsPath())
            {
                p.AddClosedCurve(arr, 0.4f);
                g.FillPath(b, p);
            }
        }

        private static void Flower(Graphics g, Brush b, float cx, float cy, float s)
        {
            var st = g.Save();
            g.TranslateTransform(cx, cy);
            g.ScaleTransform(s, s);
            for (int i = 0; i < 3; i++)
            {
                var st3 = g.Save();
                g.RotateTransform(i * 120);
                g.FillEllipse(b, -8, -24, 16, 24);
                g.Restore(st3);
            }
            g.Restore(st);
        }
    }
}
