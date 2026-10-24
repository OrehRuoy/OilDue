# Oil Due 1.0.3 TestFlight checklist

- A French iPhone shows French (Réglages, Ajouter un entretien, Permutation). German, Spanish, and Portuguese iPhones show those languages. Any other language stays English.
- App Store Connect lists English, German, French, Spanish, and Portuguese.
- Reminder for a due date of tomorrow fires at 9:00 AM local, not 9:00 UTC.
- Debug test notification still arrives about a minute later with the app killed.
- Turning Remind off cancels that reminder and does not schedule a new one.
- First run: a date on “When was your last oil change?” writes one history row and a real next date. Not sure and Skip leave oil with no next date, and the garage says Not set.
- The next screen can add tires, brakes, filters, coolant, battery, wipers, inspection, or a custom service, and Done opens the garage.
- A free garage reminds only for oil on the first car. Other services still open Unlock. Unlock lists Extra vehicles, Reminders for every service, and Archive a sold car.
- The one-time prompt “Get a reminder the morning your oil is due?” appears once. Not now does not ask again. Remind me asks for notification permission.
- An Australian region (or any region outside the mile countries) starts a new empty garage in kilometers. Stored numbers stay miles. The Settings switch flips Miles and Kilometers without rewriting old intervals. 5,000 miles still shows as 8,047 km and saves back as 5,000.
- Languages: English, German, French, Latin American Spanish, and Brazilian Portuguese. Dates and the money symbol follow the language and region.
- Opening a 1.0.1 garage keeps its cars, services, history, and unlock. Missing keys only fill in as an empty reminder list and miles.
