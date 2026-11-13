using System.Windows.Media;

namespace Vaganymester.Models;

public sealed class JournalEntry
{
    public string Time { get; }
    public string Message { get; }
    public Brush MessageBrush { get; }

    public JournalEntry(string time, string message, string level)
    {
        Time = time;
        Message = message;
        MessageBrush = level switch
        {
            "danger" => Brushes.Salmon,
            "warning" => Brushes.Gold,
            "success" => Brushes.MediumSpringGreen,
            _ => Brushes.LightSteelBlue
        };
    }
}
