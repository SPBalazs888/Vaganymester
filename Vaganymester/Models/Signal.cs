using System.Windows.Media;

namespace Vaganymester.Models;

public sealed class Signal : BindableBase
{
    public string Code { get; }
    public string Description { get; }
    public double Position { get; }
    public int Direction { get; }
    public int Track { get; }
    public double CanvasLeft { get; }
    public double CanvasTop { get; }

    private bool _isGreen;
    public bool IsGreen
    {
        get => _isGreen;
        set
        {
            if (!Set(ref _isGreen, value)) return;
            Raise(nameof(Aspect));
            Raise(nameof(LampBrush));
        }
    }

    public string Aspect => IsGreen ? "SZABAD" : "MEGÁLLJ";
    public Brush LampBrush => IsGreen ? Brushes.LimeGreen : Brushes.OrangeRed;

    public Signal(string code, string description, double position, int direction,
        int track, double canvasLeft, double canvasTop)
    {
        Code = code;
        Description = description;
        Position = position;
        Direction = direction;
        Track = track;
        CanvasLeft = canvasLeft;
        CanvasTop = canvasTop;
    }
}
