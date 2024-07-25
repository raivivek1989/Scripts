import json

def extract_line_number(error_message):
  start_index = str(error_message).find("line ") + len("line ")
  end_index = str(error_message).find(" column")
  if start_index != -1 and end_index != -1:
    try:
      line_number = int(str(error_message)[start_index:end_index])
      return line_number
    except ValueError:
      return None
  else:
    return None

def highlight_line(text, line_number):
  lines = text.splitlines()
  if 1 <= line_number <= len(lines):
    lines[line_number - 1] = f"> {lines[line_number - 1]}"
    return "\n".join(lines)
  else:
    return f"Invalid line number: {line_number}"

def verify_json_string(json_str):
    try:
        json.loads(json_str)
        return True
    except json.JSONDecodeError as e:
        print(f"Invalid JSON: {e}")
        line_number = extract_line_number(e)
        highlighted_text = highlight_line(json_str, line_number)
        print(highlighted_text)
        return False
    
# Example:
json_string = """
{
    "name": "John Doe",
    "city": "New York",
    "age": 30,
    "occupation": "
    Software Engineer
    ",
    "hobbies": ["reading", "coding", "hiking"],
    "address": {
        "street": "123 Main St",
        "zipcode": "10001"
    }
}
"""

verify_json_string(json_string)