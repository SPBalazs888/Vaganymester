using System.Windows;
using System.Windows.Controls;
using Vaganymester.Models;

namespace Vaganymester;

public partial class TrainDetailsWindow : Window
{
    private readonly Train _train;
    private TrainSeat? _selectedSeat;

    public TrainDetailsWindow(Train train)
    {
        InitializeComponent();
        _train = train;
        DataContext = train;
        Title = $"{train.Number} – utastér | VÁGÁNYMESTER";
        if (train.Type == TrainType.Teher)
        {
            PassengerLayout.Visibility = Visibility.Collapsed;
            FreightBanner.Visibility = Visibility.Visible;
        }
        else
        {
            CarriageList.SelectedIndex = 0;
        }
    }

    private void CarriageList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selectedSeat = null;
        SeatInfo.Text = "Válassz egy ülést a rajzon!";
        PassengerNameBox.Clear();
    }

    private void Seat_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: TrainSeat seat }) return;
        _selectedSeat = seat;
        PassengerNameBox.Text = seat.Passenger?.Name ?? "";
        SeatInfo.Text = seat.Passenger is null
            ? $"{seat.Label} – szabad ülés. Írj be egy utasnevet."
            : $"{seat.Label} – {seat.Passenger.Name} • {seat.Passenger.Ticket}.";
    }

    private void Board_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedSeat is null || CarriageList.SelectedItem is not TrainCarriage carriage)
        {
            MessageBox.Show(this, "Először kattints egy ülésre!", "Ülésválasztás");
            return;
        }
        string name = PassengerNameBox.Text.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            MessageBox.Show(this, "Add meg az utas nevét!", "Hiányzó név");
            return;
        }
        string from = _train.Direction > 0 ? "Nyugati végállomás" : "Keleti végállomás";
        carriage.Assign(_selectedSeat, new Passenger(name, from, _train.Destination, "Teljes árú"));
        SeatInfo.Text = $"{_selectedSeat.Label} – {name} • Teljes árú.";
    }

    private void Remove_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedSeat is null || CarriageList.SelectedItem is not TrainCarriage carriage)
        {
            MessageBox.Show(this, "Először kattints egy ülésre!", "Ülésválasztás");
            return;
        }
        carriage.Assign(_selectedSeat, null);
        PassengerNameBox.Clear();
        SeatInfo.Text = $"{_selectedSeat.Label} – szabad ülés.";
    }
}
