using System.Windows.Media;

namespace Vaganymester.Models;

public sealed class Turnout : BindableBase
{
    public string Code { get; }
    public string Description { get; }
    public double CanvasLeft { get; }
    public double CanvasTop { get; }

    private int _track;
    public int Track
    {
        get => _track;
        set
        {
            if (!Set(ref _track, value)) return;
            Raise(nameof(RouteText));
            Raise(nameof(StraightBrush));
            Raise(nameof(BranchBrush));
        }
    }

    private bool _isLocked;
    public bool IsLocked
    {
        get => _isLocked;
        set
        {
            if (!Set(ref _isLocked, value)) return;
            Raise(nameof(LockText));
        }
    }

    public string RouteText => Track == 0 ? "1. vágány (egyenes)" : "2. vágány (kitérő)";
    public string LockText => IsLocked ? "LEZÁRVA" : "ÁLLÍTHATÓ";
    public Brush StraightBrush => Track == 0 ? Brushes.MediumSpringGreen : Brushes.SlateGray;
    public Brush BranchBrush => Track == 1 ? Brushes.MediumSpringGreen : Brushes.SlateGray;

    public Turnout(string code, string description, double canvasLeft, double canvasTop)
    {
        Code = code;
        Description = description;
        CanvasLeft = canvasLeft;
        CanvasTop = canvasTop;
    }
}
