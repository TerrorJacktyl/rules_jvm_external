def unpack_coordinates(coords):
    """Takes a maven coordinate and unpacks it into a struct with fields
    `groupId`, `artifactId`, `version`, `type`, `scope`
    where type and scope are optional.

    Assumes following maven coordinate syntax:
    groupId:artifactId[:type[:scope]]:version
    """
    if not coords:
        return None

    parts = coords.split(":")
    nparts = len(parts)

    if nparts == 2:
        return struct(
            groupId = parts[0],
            artifactId = parts[1],
            type = None,
            scope = None,
            version = None,
        )

    if nparts < 3 or nparts > 5:
        fail("Unparsed: %s" % coords)

    version = parts[-1]
    parts = dict(enumerate(parts[:-1]))
    return struct(
        groupId = parts.get(0),
        artifactId = parts.get(1),
        type = parts.get(2),
        scope = parts.get(3),
        version = version,
    )

def _whitespace(indent):
    whitespace = ""
    for i in range(indent):
        whitespace = whitespace + " "
    return whitespace

def format_dep(unpacked, indent = 8, include_version = True):
    whitespace = _whitespace(indent)

    dependency = [
        whitespace,
        "<dependency>\n",
        whitespace,
        "    <groupId>%s</groupId>\n" % unpacked.groupId,
        whitespace,
        "    <artifactId>%s</artifactId>\n" % unpacked.artifactId,
    ]

    if include_version:
        dependency.extend([
            whitespace,
            "    <version>%s</version>\n" % unpacked.version,
        ])

    if unpacked.type and unpacked.type != "jar":
        dependency.extend([
            whitespace,
            "    <type>%s</type>\n" % unpacked.type,
        ])

    if unpacked.scope and unpacked.scope != "compile":
        dependency.extend([
            whitespace,
            "    <scope>%s</scope>\n" % unpacked.scope,
        ])

    dependency.extend([
        whitespace,
        "</dependency>",
    ])

    return "".join(dependency)

def generate_pom(
        ctx,
        coordinates,
        pom_template,
        out_name,
        parent = None,
        versioned_dep_coordinates = [],
        unversioned_dep_coordinates = [],
        indent = 8):
    unpacked_coordinates = unpack_coordinates(coordinates)
    substitutions = {
        "{groupId}": unpacked_coordinates.groupId,
        "{artifactId}": unpacked_coordinates.artifactId,
        "{version}": unpacked_coordinates.version,
        "{type}": unpacked_coordinates.type or "jar",
        "{scope}": unpacked_coordinates.scope or "compile",
    }

    if parent:
        # We only want the groupId, artifactID, and version
        unpacked_parent = unpack_coordinates(parent)

        whitespace = _whitespace(indent - 4)
        parts = [
            whitespace,
            "    <groupId>%s</groupId>\n" % unpacked_parent.groupId,
            whitespace,
            "    <artifactId>%s</artifactId>\n" % unpacked_parent.artifactId,
            whitespace,
            "    <version>%s</version>" % unpacked_parent.version,
        ]
        substitutions.update({"{parent}": "".join(parts)})

    deps = []
    for dep in sorted(versioned_dep_coordinates):
        unpacked = unpack_coordinates(dep)
        deps.append(format_dep(unpacked, indent = indent))
    for dep in sorted(unversioned_dep_coordinates):
        unpacked = unpack_coordinates(dep)
        deps.append(format_dep(unpacked, indent = indent, include_version = False))

    substitutions.update({"{dependencies}": "\n".join(deps)})

    out = ctx.actions.declare_file("%s" % out_name)
    ctx.actions.expand_template(
        template = pom_template,
        output = out,
        substitutions = substitutions,
    )

    return out
