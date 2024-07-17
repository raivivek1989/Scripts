import json

# Sample JSON data
data = {
  "name": "Vivek Rai",
  "age": 34,
  "city": "Whitefield \n Bengaluru \n Karnataka",
  "skills": ["Python", "DevOps", "Cloud"]
}

# Writing JSON data to a file
with open("data.json", "w") as outfile:
  json.dump(data, outfile, indent=4)
  print("Data written to data.json")

# Reading JSON data from a file
with open("data.json", "r") as infile:
  loaded_data = json.load(infile)
  print("Loaded data:")
  print(loaded_data)

# Accessing data from the loaded JSON
name = loaded_data["name"]
age = loaded_data["age"]

print(f"Name: {name}, Age: {age}")

# Modifying data and writing it back (optional)
loaded_data["city"] = "Bengaluru \n Karnataka"
with open("data.json", "w") as outfile:
  json.dump(loaded_data, outfile, indent=4)
  print("Data updated and written back to data.json")
