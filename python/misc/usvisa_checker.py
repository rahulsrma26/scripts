"""
US Visa availability checker
============================
This script checks the availability of US Visa dates and notifies the user when a date is available.
The script uses the requests library to fetch the data from the US Visa website.
The script uses the espeak command to notify the user when a date is available.

Requirements:
1. Python 3.9 or higher
2. requests library (pip install requests)
3. install espeak command
    a. Linux/Debian: sudo apt install espeak
    b. Mac: brew install espeak
    c. Windows: winget install -e --id espeak.espeak

Usage:
1. Login to the US Visa website (ais.usvisa-info.com) and navigate to the reschedule appointment page.
2. Select the location and enter the details to check the availability of dates.
3. Open the browser developer tools and go to the network tab.
4. Copy the request URL and request header raw from the browser.
5. Update the REQUEST_URL and REQUEST_HEADER variables in the script.
6. Run the script using the python command.
"""

import os
import asyncio
import random
import requests
import datetime

BEST_BEFORE = "2024-09-15"  # YYYY-MM-DD
CHECK_FREQUENCY = (30, 60)  # 30 to 60 seconds
REQUEST_URL = ""
REQUEST_HEADER = """
"""

headers = {
    k: v
    for k, v in (line.split(": ", 1) for line in REQUEST_HEADER.strip().split("\n"))
}
random.seed()


async def main():
    os.system("espeak 'US Visa availability checker'")
    while True:
        response = requests.get(REQUEST_URL, headers=headers)
        if response.status_code != 200:
            os.system("espeak 'Error fetching data'")
            print(f"Error fetching data: {response.status_code}.")
            print("Copy the request header from the browser and update the script.")
            break
        dates = sorted(
            [
                datetime.datetime.strptime(item["date"], "%Y-%m-%d").date()
                for item in response.json()
                if "date" in item
            ]
        )
        useful_dates = [
            date for date in dates if date < datetime.date.fromisoformat(BEST_BEFORE)
        ]
        print(f"US Visa dates available from {dates[0]}")
        if useful_dates:
            print("-" * 40)
            print(f"Best date: {useful_dates[0]}")
            os.system(
                f"espeak 'US Visa dates available from {useful_dates[0].strftime('%B %d, %Y')}'"
            )
        next_check = datetime.datetime.now() + datetime.timedelta(
            seconds=random.randint(*CHECK_FREQUENCY)
        )
        while (now := datetime.datetime.now()) < next_check:
            delay = int((next_check - now).total_seconds())
            print(f"Next check in {delay:02d} seconds", end="\r")
            await asyncio.sleep(1)


asyncio.run(main())
