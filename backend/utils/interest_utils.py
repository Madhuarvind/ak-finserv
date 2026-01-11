from datetime import timedelta


def calculate_flat_emi(principal, annual_rate, tenure_count, tenure_unit):
    """
    Calculates EMI schedule for Flat Interest logic.
    Commonly used in simple microfinance workflows.
    Total Interest = (Principal * Rate * Tenure) / (conversion factor)
    """
    # Normalize tenure to yearly for rate application if needed,
    # but MFIs usually apply rate directly to principal for the whole tenure.
    # Standard MFI Flat: Total Interest = Principal * (Rate/100)
    # This assumes specified rate IS for the tenure.

    total_interest = principal * (annual_rate / 100)
    total_payable = principal + total_interest
    emi_amount = total_payable / tenure_count

    schedule = []
    balance = total_payable

    # For Flat, principal and interest portions are often kept constant for simplicity
    p_part = principal / tenure_count
    i_part = total_interest / tenure_count

    for i in range(1, tenure_count + 1):
        balance -= emi_amount
        schedule.append(
            {
                "emi_no": i,
                "amount": round(emi_amount, 2),
                "principal_part": round(p_part, 2),
                "interest_part": round(i_part, 2),
                "balance": round(max(0, balance), 2),
            }
        )

    return schedule


def calculate_reducing_emi(principal, annual_rate, tenure_count, tenure_unit):
    """
    Calculates EMI schedule for Reducing Balance logic.
    Uses amortization formula.
    """
    # Convert annual rate to periodic rate
    if tenure_unit == "months":
        periodic_rate = (annual_rate / 100) / 12
    elif tenure_unit == "weeks":
        periodic_rate = (annual_rate / 100) / 52
    else:  # days
        periodic_rate = (annual_rate / 100) / 365

    if periodic_rate == 0:
        emi_amount = principal / tenure_count
    else:
        emi_amount = (
            principal
            * (periodic_rate * (1 + periodic_rate) ** tenure_count)
            / ((1 + periodic_rate) ** tenure_count - 1)
        )

    schedule = []
    current_balance = principal

    for i in range(1, tenure_count + 1):
        interest_part = current_balance * periodic_rate
        principal_part = emi_amount - interest_part
        current_balance -= principal_part

        schedule.append(
            {
                "emi_no": i,
                "amount": round(emi_amount, 2),
                "principal_part": round(principal_part, 2),
                "interest_part": round(interest_part, 2),
                "balance": round(max(0, current_balance), 2),
            }
        )

    return schedule


def generate_dates(start_date, count, unit):
    dates = []
    curr = start_date
    for _ in range(count):
        if unit == "days":
            curr += timedelta(days=1)
        elif unit == "weeks":
            curr += timedelta(weeks=1)
        elif unit == "months":
            # Robust month addition
            month = curr.month + 1
            year = curr.year
            if month > 12:
                month = 1
                year += 1

            # Handle month-end issues (e.g., Jan 31 -> Feb 28/29)
            import calendar

            last_day = calendar.monthrange(year, month)[1]
            day = min(curr.day, last_day)
            curr = curr.replace(year=year, month=month, day=day)
        dates.append(curr)
    return dates


def get_distance_meters(lat1, lon1, lat2, lon2):
    """
    Calculate the great circle distance between two points
    on the earth (specified in decimal degrees)
    """
    import math

    if None in [lat1, lon1, lat2, lon2]:
        return 999999

    # Convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

    # Haversine formula
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.asin(math.sqrt(a))
    r = 6371000  # Radius of earth in meters. Use 3956 for miles
    return c * r
