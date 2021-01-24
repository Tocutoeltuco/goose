import os
import re


src = "./src"
docs = "./docs"


# Try to create directory if it doesn't exist
try:
	os.mkdir(docs)
except Exception:
	pass


# Wipe directory if it has any file
for file in os.listdir(docs):
	os.remove("{}/{}".format(docs, file))


# Read documentation comments
comments = []

def scan(path=src):
	for name in os.listdir(path):
		name = "{}/{}".format(path, name)

		if os.path.isdir(name):
			# Recursively scan directory
			scan(name)

		elif name.endswith(".lua"):
			# Ignore any file that doesn't end in .lua
			with open(name, "r") as file:
				comments.extend(re.findall(
					r"--\[\[(@.+?)\]\]\s+([^\n]+)",
					file.read(), re.S
				))


def parse_param(text):
	# [?]param[<type>] description
	param_str, desc = text.split(" ", 1)

	param = {
		"optional": False,
		"name": None,
		"type": ["any"],
		"description": re.sub(r"\s+", " ", desc)
	}

	if param_str[0] == "?":
		param["optional"] = True
		param_str = param_str[1:]

	if "<" in param_str:
		# yes, it is supposed to be type but that's a function
		param_str, tipe = param_str.split("<", 1)
		tipe = tipe[:-1] # remove >
		param["type"] = tipe.split(",")

	param["name"] = param_str
	return param


scan()

# Parse comments
objects = {}
functions = []

for comment, line in comments:
	description = []
	attributes = []
	parameters = []
	returns = []
	available = None
	name = None

	for instruction in comment.split("@"):
		if not instruction:
			continue

		command, rest = instruction.split(" ", 1)
		rest = rest.strip()

		if command in ("", "desc"):
			# replace multiple spaces with a single one
			description.append(re.sub(r"\s+", " ", rest))

		elif command == "param":
			# function parameters
			parameters.append(parse_param(rest))

		elif command == "returns":
			# return type
			# yes, it is supposed to be type but that's a function
			tipe, desc = rest.split(" ", 1)
			returns.append((tipe, re.sub(r"\s+", " ", desc)))

		elif command == "attribute":
			# object attribute
			attributes.append(parse_param(rest))

		elif command == "available":
			# available when preprocess directive
			available = rest.replace("|", "or").replace("&", "and")

		elif command == "name":
			# ignore next line, use this name
			name = rest

		else:
			print("unknown command: {}".format(command))

	if name is None:
		# No @name command, guessing from next line
		line = re.sub(r"--.+", "", line).strip() # remove comment

		if "=" in line: # definition (name = something)
			name = line.split("=", 1)[0].strip()

		elif "function" in line: # function sugar syntax (function name())
			# Ignore parentheses
			name = line.split(" ", 1)[1].split("(", 1)[0].strip()

		else:
			print("unknown definition: {}".format(line))

	if "." not in name and ":" not in name: # Class
		objects[name] = {
			"name": name,
			"available": available,
			"attributes": attributes,
			"description": description,
			"methods": []
		}

	else: # Function
		functions.append({
			"name": name,
			"available": available,
			"parameters": parameters,
			"returns": returns,
			"description": description
		})

for function in functions:
	separator = function["separator"] = "." if "." in function["name"] else ":"

	# yes, it is supposed to be class but that would throw a syntax error
	klass, function["name"] = function["name"].split(separator, 1)
	objects[klass]["methods"].append(function)


# Generate markdown files
def get_type(type_list):
	if "any" in type_list:
		return "`any`"

	types = []
	for tipe in type_list:
		if tipe[0].isupper(): # Custom class
			types.append("[`{0}`]({0}.md#{0})".format(tipe))

		else:
			types.append("`{}`".format(tipe))

	return ", ".join(types)


readme = ["# Goose Documentation\n\n## API Reference"]
files = {"README.md": readme}

for klass, data in objects.items():
	content = ["# Goose Documentation\n"]
	files["{}.md".format(klass)] = content

	# Class name and description
	readme.append("* [{0}]({0}.md)".format(klass))
	content.append("## {}".format(klass))
	content.append("\n\n".join(data["description"]))

	if data["available"] is not None:
		content.append(
			"\nThis class is only available when the following preprocessing"
			" variables are true: `{}`"
			.format(data["available"])
		)

	# Attributes
	content.append("\n| Attribute | Type | Can be nil | Description |")
	content.append("| :-: | :-: | :-: | :-- |")
	for attribute in data["attributes"]:
		content.append(
			"| {} | {} | {} | {} |"
			.format(
				attribute["name"],
				get_type(attribute["type"]),
				"✔" if attribute["optional"] else "✕",
				attribute["description"]
			)
		)

	# Methods
	content.append("\n### Methods")
	for method in data["methods"]:
		readme.append(
			"  * [{0}{1}{2}]({0}.md#{0}.{3})"
			.format(
				klass, method["separator"],
				method["name"].replace("_", "\\_"), method["name"]
			)
		)

		parameters = ", ".join(
			map(lambda param: param["name"], method["parameters"])
		)

		content.append(
			'{0}{1}**{2}**({3}) <a id="{0}.{4}" href="#{0}.{4}">¶</a>\n>'
			.format(
				klass, method["separator"], method["name"].replace("_", "\\_"),
				"_{}_".format(parameters) if parameters else "",
				method["name"]
			)
		)
		content.append(">" + ("\n>\n>".join(method["description"])))

		if method["available"] is not None:
			content.append(
				">\n>This method is only available when the following"
				" preprocessing variables are true: `{}`"
				.format(method["available"])
			)

		if method["parameters"]:
			content.append(">\n>| Parameter | Type | Can be nil | Description |")
			content.append(">| :-: | :-: | :-: | :-- |")
			for parameter in method["parameters"]:
				content.append(
					">| {} | {} | {} | {} |"
					.format(
						parameter["name"],
						get_type(parameter["type"]),
						"✔" if parameter["optional"] else "✕",
						parameter["description"]
					)
				)

		if method["returns"]:
			content.append(">\n>| Returns | Description |")
			content.append(">| :-: | :-- |")
			for tipe, desc in method["returns"]:
				content.append(">| {} | {} |".format(get_type((tipe,)), desc))

		content.append("\n---\n")

for name, content in files.items():
	with open("{}/{}".format(docs, name), "wb") as file:
		file.write("\n".join(content).encode())