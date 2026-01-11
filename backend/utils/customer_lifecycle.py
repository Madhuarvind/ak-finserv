# Customer Lifecycle Management Utilities
# Add this to a new file: utils/customer_lifecycle.py

VALID_STATUS_TRANSITIONS = {
    "created": ["verified", "inactive"],
    "verified": ["active", "inactive"],
    "active": ["inactive", "closed"],
    "inactive": ["active", "closed"],
    "closed": [],  # Terminal state
}


def can_transition_status(current_status, new_status):
    """
    Check if status transition is valid
    """
    if current_status == new_status:
        return True

    allowed = VALID_STATUS_TRANSITIONS.get(current_status, [])
    return new_status in allowed


def get_status_color(status):
    """
    Get color code for status badge
    """
    colors = {
        "created": "#FFA500",  # Orange
        "verified": "#1E90FF",  # Blue
        "active": "#28a745",  # Green
        "inactive": "#6c757d",  # Gray
        "closed": "#dc3545",  # Red
    }
    return colors.get(status, "#6c757d")


def validate_status_transition(current_status, new_status, user_role):
    """
    Validate status transition with role checks
    """
    if not can_transition_status(current_status, new_status):
        return False, f"Cannot transition from {current_status} to {new_status}"

    # Only admins can close customers
    if new_status == "closed" and user_role != "ADMIN":
        return False, "Only admins can close customers"

    return True, "Valid transition"
