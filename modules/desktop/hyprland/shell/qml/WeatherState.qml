pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: weather

    required property RuntimeConfig runtime

    readonly property string preferredLocation: Quickshell.env("LINUX_DESKTOP_WEATHER_LOCATION") || ""
    property string city: ""
    property string status: "Locating…"
    property bool loading: false
    property bool available: false
    property real latitude: NaN
    property real longitude: NaN
    property real temperature: 0
    property real feelsLike: 0
    property int humidity: 0
    property real windSpeed: 0
    property int weatherCode: -1
    property bool isDay: true
    property string sunrise: ""
    property string sunset: ""
    property var forecast: []
    property string updatedAt: ""

    readonly property string icon: symbolFor(weatherCode, isDay)
    readonly property string description: conditionFor(weatherCode)

    function symbolFor(code: int, daylight: bool): string {
        if (code === 0)
            return daylight ? "󰖙" : "󰖔";
        if (code <= 2)
            return daylight ? "󰖕" : "󰖔";
        if (code === 3)
            return "󰖐";
        if (code === 45 || code === 48)
            return "󰖑";
        if (code >= 51 && code <= 57)
            return "󰖗";
        if (code >= 61 && code <= 67 || code >= 80 && code <= 82)
            return "󰖖";
        if (code >= 71 && code <= 77 || code >= 85 && code <= 86)
            return "󰖘";
        if (code >= 95)
            return "󰖓";
        return "󰖐";
    }

    function conditionFor(code: int): string {
        if (code === 0)
            return "Clear sky";
        if (code <= 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code === 45 || code === 48)
            return "Foggy";
        if (code >= 51 && code <= 57)
            return "Drizzle";
        if (code >= 61 && code <= 67)
            return "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Rain showers";
        if (code >= 85 && code <= 86)
            return "Snow showers";
        if (code >= 95)
            return "Thunderstorms";
        return "Weather unavailable";
    }

    function temperatureText(value: real): string {
        return Math.round(value) + "°";
    }

    function timeText(value: string): string {
        return value ? Qt.formatTime(new Date(value), "h:mm AP") : "--:--";
    }

    function refresh(): void {
        if (loading)
            return;
        loading = true;
        status = available ? "Refreshing…" : "Locating…";
        if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
            fetchForecast();
        } else {
            lookupLocation();
        }
    }

    function lookupLocation(): void {
        const preference = preferredLocation.trim();
        if (preference.length > 0) {
            const coords = preference.split(",").map(part => Number(part.trim()));
            if (coords.length === 2 && coords.every(Number.isFinite) && Math.abs(coords[0]) <= 90 && Math.abs(coords[1]) <= 180) {
                city = "Selected location";
                latitude = coords[0];
                longitude = coords[1];
                fetchForecast();
                return;
            }
        }

        locationRequest.command = [runtime.weatherCurl, "--fail", "--silent", "--show-error", "--connect-timeout", "6", "--max-time", "15", preference.length > 0 ? "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(preference) + "&count=1&format=json" : "https://ipwho.is/?fields=success,city,latitude,longitude"];
        locationRequest.running = true;
    }

    function fetchForecast(): void {
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            loading = false;
            status = "Location unavailable";
            return;
        }
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max" + "&timezone=auto&forecast_days=7";
        forecastRequest.command = [runtime.weatherCurl, "--fail", "--silent", "--show-error", "--connect-timeout", "6", "--max-time", "15", url];
        forecastRequest.running = true;
    }

    property Process locationRequest: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const place = weather.preferredLocation.trim() ? data.results?.[0] : data;
                    if (!place || (!weather.preferredLocation.trim() && place.success !== true))
                        throw new Error("No matching location");
                    weather.latitude = Number(place.latitude);
                    weather.longitude = Number(place.longitude);
                    weather.city = String(place.name || place.city || "Unknown location");
                    weather.fetchForecast();
                } catch (error) {
                    weather.status = "Location unavailable";
                    weather.loading = false;
                }
            }
        }
    }

    property Process forecastRequest: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.current || !data.daily || data.daily.time.length !== 7)
                        throw new Error("Incomplete forecast");
                    weather.temperature = data.current.temperature_2m;
                    weather.feelsLike = data.current.apparent_temperature;
                    weather.humidity = data.current.relative_humidity_2m;
                    weather.windSpeed = data.current.wind_speed_10m;
                    weather.weatherCode = data.current.weather_code;
                    weather.isDay = data.current.is_day === 1;
                    weather.sunrise = data.daily.sunrise[0];
                    weather.sunset = data.daily.sunset[0];
                    const days = [];
                    for (let i = 0; i < data.daily.time.length; i++) {
                        days.push({
                            date: data.daily.time[i],
                            code: data.daily.weather_code[i],
                            high: data.daily.temperature_2m_max[i],
                            low: data.daily.temperature_2m_min[i],
                            rain: data.daily.precipitation_probability_max[i]
                        });
                    }
                    weather.forecast = days;
                    weather.updatedAt = Qt.formatTime(new Date(), "h:mm AP");
                    weather.available = true;
                    weather.status = "";
                } catch (error) {
                    weather.status = "Forecast unavailable";
                }
                weather.loading = false;
            }
        }
    }

    property Timer refreshTimer: Timer {
        running: true
        triggeredOnStart: true
        repeat: true
        interval: 15 * 60 * 1000
        onTriggered: weather.refresh()
    }
}
