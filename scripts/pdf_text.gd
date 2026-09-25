extends RefCounted
class_name PdfText

const PAGE_W := 612
const PAGE_H := 792
const MARGIN_X := 54
const MARGIN_TOP := 54
const MARGIN_BOTTOM := 54
const FONT_SIZE := 11
const LINE_H := 14
const WRAP := 72
const FOOTER := "Oil Due"


static func render(lines: PackedStringArray) -> PackedByteArray:
	var wrapped: PackedStringArray = PackedStringArray()
	for line in lines:
		var raw := str(line)
		if raw == "":
			wrapped.append("")
			continue
		for part in _wrap(raw, WRAP):
			wrapped.append(part)
	var pages: Array = []
	var current: PackedStringArray = PackedStringArray()
	var y := PAGE_H - MARGIN_TOP
	var limit := MARGIN_BOTTOM + LINE_H
	for line in wrapped:
		if y < limit and not current.is_empty():
			pages.append(current)
			current = PackedStringArray()
			y = PAGE_H - MARGIN_TOP
		current.append(line)
		y -= LINE_H
	if current.is_empty():
		current.append("")
	pages.append(current)
	return _build(pages)


static func _wrap(text: String, width: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur := ""
	for piece in text.split(" ", false):
		var word := str(piece)
		while word.length() > width:
			if cur != "":
				out.append(cur)
				cur = ""
			out.append(word.substr(0, width))
			word = word.substr(width)
		if word == "":
			continue
		if cur == "":
			cur = word
		elif cur.length() + 1 + word.length() <= width:
			cur += " " + word
		else:
			out.append(cur)
			cur = word
	if cur != "":
		out.append(cur)
	if out.is_empty():
		out.append("")
	return out


static func _build(pages: Array) -> PackedByteArray:
	var n_pages := pages.size()
	var kids := ""
	for i in n_pages:
		if kids != "":
			kids += " "
		kids += "%d 0 R" % (4 + i * 2)
	var objects: Array[String] = []
	objects.append("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	objects.append("2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n" % [kids, n_pages])
	objects.append("3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n")
	for i in n_pages:
		var page_lines: PackedStringArray = pages[i]
		var stream := _content(page_lines)
		var page_num := 4 + i * 2
		var content_num := page_num + 1
		objects.append(
			"%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] /Contents %d 0 R /Resources << /Font << /F1 3 0 R >> >> >>\nendobj\n"
			% [page_num, PAGE_W, PAGE_H, content_num]
		)
		objects.append(
			"%d 0 obj\n<< /Length %d >>\nstream\n%sendstream\nendobj\n" % [content_num, stream.length(), stream]
		)
	var body := "%PDF-1.4\n"
	var offsets: Array[int] = [0]
	for obj in objects:
		offsets.append(body.length())
		body += obj
	var xref_pos := body.length()
	var xref := "xref\n0 %d\n" % (objects.size() + 1)
	xref += "0000000000 65535 f \n"
	for i in range(1, offsets.size()):
		xref += "%010d 00000 n \n" % offsets[i]
	var trailer := "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % [objects.size() + 1, xref_pos]
	return (body + xref + trailer).to_utf8_buffer()


static func _content(lines: PackedStringArray) -> String:
	var y := PAGE_H - MARGIN_TOP
	var parts: PackedStringArray = PackedStringArray()
	parts.append("BT")
	parts.append("/F1 %d Tf" % FONT_SIZE)
	var first := true
	for line in lines:
		if first:
			parts.append("%d %d Td" % [MARGIN_X, y])
			first = false
		else:
			parts.append("0 -%d Td" % LINE_H)
		parts.append("%s Tj" % _literal(line))
	parts.append("ET")
	parts.append("BT")
	parts.append("/F1 9 Tf")
	parts.append("%d 36 Td" % MARGIN_X)
	parts.append("%s Tj" % _literal(FOOTER))
	parts.append("ET")
	return "\n".join(parts) + "\n"


static func _literal(text: String) -> String:
	var out := "("
	var i := 0
	while i < text.length():
		var cp := text.unicode_at(i)
		var byte := _winansi_byte(cp)
		if byte < 0:
			out += "?"
		elif byte == 0x5C:
			out += "\\\\"
		elif byte == 0x28 or byte == 0x29:
			out += "\\" + char(byte)
		elif byte < 32 or byte > 126:
			out += "\\%03o" % byte
		else:
			out += char(byte)
		i += 1
	out += ")"
	return out


static func _winansi_byte(cp: int) -> int:
	if cp >= 32 and cp <= 126:
		return cp
	if cp >= 160 and cp <= 255:
		return cp
	match cp:
		0x2018, 0x2019:
			return 39
		0x201C, 0x201D:
			return 34
		0x2013, 0x2014:
			return 45
		0x20AC:
			return 0x80
		_:
			return -1
