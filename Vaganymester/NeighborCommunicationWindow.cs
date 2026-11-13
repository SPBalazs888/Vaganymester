using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;

namespace Vaganymester;

/// <summary>Simple UI for viewing and sending messages to neighboring stations.</summary>
public sealed class NeighborCommunicationWindow : Window
{
    private readonly Action<string> _sendMessage;
    private readonly TextBox _messageInput;

    public NeighborCommunicationWindow(ObservableCollection<string> messages, Action<string> sendMessage)
    {
        _sendMessage = sendMessage;
        Title = "Állomásközi kommunikáció";
        Width = 560;
        Height = 420;
        MinWidth = 400;
        MinHeight = 300;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;

        var layout = new DockPanel { Margin = new Thickness(12) };
        var composePanel = new DockPanel { LastChildFill = true, Margin = new Thickness(0, 10, 0, 0) };
        DockPanel.SetDock(composePanel, Dock.Bottom);

        var sendButton = new Button
        {
            Content = "Küldés",
            MinWidth = 90,
            Margin = new Thickness(8, 0, 0, 0),
            Padding = new Thickness(10, 5, 10, 5)
        };
        sendButton.Click += (_, _) => SendCurrentMessage();
        DockPanel.SetDock(sendButton, Dock.Right);
        composePanel.Children.Add(sendButton);

        _messageInput = new TextBox
        {
            MinHeight = 30,
            VerticalContentAlignment = VerticalAlignment.Center,
            ToolTip = "Írd be a szomszédos állomásnak küldendő üzenetet"
        };
        _messageInput.KeyDown += (_, e) =>
        {
            if (e.Key == System.Windows.Input.Key.Enter)
            {
                SendCurrentMessage();
                e.Handled = true;
            }
        };
        composePanel.Children.Add(_messageInput);
        layout.Children.Add(composePanel);

        var messageList = new ListBox
        {
            ItemsSource = messages,
            BorderThickness = new Thickness(0),
            HorizontalContentAlignment = HorizontalAlignment.Stretch
        };
        messageList.SetBinding(BackgroundProperty, new Binding("Background")
        {
            Source = this
        });
        layout.Children.Add(messageList);
        Content = layout;
    }

    private void SendCurrentMessage()
    {
        string message = _messageInput.Text.Trim();
        if (message.Length == 0) return;

        _sendMessage(message);
        _messageInput.Clear();
        _messageInput.Focus();
    }
}
