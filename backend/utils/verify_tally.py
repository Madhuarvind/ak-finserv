
import xml.etree.ElementTree as ET

def verify_tally_xml(xml_content):
    try:
        root = ET.fromstring(xml_content)
        if root.tag != "ENVELOPE":
            print("Error: Root tag must be ENVELOPE")
            return False
            
        tally_msg = root.find(".//TALLYMESSAGE")
        if tally_msg is None:
            print("Error: TALLYMESSAGE not found")
            return False
            
        voucher = tally_msg.find("VOUCHER")
        if voucher is None:
            print("Error: VOUCHER not found")
            return False
            
        print("Success: Valid Tally XML structure detected.")
        return True
    except Exception as e:
        print(f"XML Parsing Error: {e}")
        return False

# Example usage (you can pipe output to this)
if __name__ == "__main__":
    import sys
    # Verify stdin if piped
    if not sys.stdin.isatty():
        content = sys.stdin.read()
        verify_tally_xml(content)
