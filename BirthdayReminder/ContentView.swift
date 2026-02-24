import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BirthdayListView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
}
