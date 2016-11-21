# pure ruby library to encode/decode json strings
# Y Guillot, 01/2013
# WtfPLv2

module JSON
	# ruby object -> json string
	def self.generate(obj)
		case obj
		when ::Hash
			'{ ' + obj.map { |k, v| generate(k) + ': ' + generate(v) }.join(', ') + ' }'
		when ::Array
			'[ ' + obj.map { |v| generate(v) }.join(', ') + ' ]'
		when ::Integer, ::Float
			obj.to_s
		when ::String
			'"' + obj.unpack('C*').map { |c| (c == 0x22 or c == 0x5c or c < 0x20 or c > 0x7e) ? '\\u%04X' % c : c.chr }.join + '"'
		when true
			'true'
		when false
			'false'
		when nil
			'null'
		else
			raise "JSON: cannot serialize #{obj.inspect}"
		end
	end


	class ParseError < RuntimeError ; end

	# json string -> ruby object
	def self.parse(str, poff=[0])
		parse_skipspc(str, poff)
		case str[poff[0]]
		when nil
			raise ParseError, "JSON: unexpected EOS"

		when ?{
			poff[0] += 1
			out = {}
			parse_skipspc(str, poff)
			if str[poff[0]] == ?}
				poff[0] += 1
				return out
			end

			loop do
				k = parse(str, poff)

				parse_skipspc(str, poff)
				raise ParseError, "JSON: expected ':', got #{str[poff[0], 4].inspect}" if str[poff[0]] != ?:
				poff[0] += 1

				out[k] = parse(str, poff)

				parse_skipspc(str, poff)
				case str[poff[0]]
				when ?,
					poff[0] += 1
				when ?}
					poff[0] += 1
					break
				else
					raise ParseError, "JSON: expected ',' or '}', got #{str[poff[0], 4].inspect}"
				end
			end
			out

		when ?[
			poff[0] += 1
			out = []
			parse_skipspc(str, poff)
			if str[poff[0]] == ?]
				poff[0] += 1
				return out
			end

			loop do
				out << parse(str, poff)

				parse_skipspc(str, poff)
				case str[poff[0]]
				when ?,
					poff[0] += 1
				when ?]
					poff[0] += 1
					break
				else
					raise ParseError, "JSON: expected ',' or ']', got #{str[poff[0], 4].inspect}"
				end
			end
			out

		when ?"
			poff[0] += 1
			out = ''
			loop do
				case c = str[poff[0]]
				when nil
					raise ParseError, "JSON: unexpected EOS in string"
				when ?"
					poff[0] += 1
					break
				when ?\\
					poff[0] += 1
					out << parse_str_escape(str, poff)
				else
					poff[0] += 1
					out << c
				end
			end
			out

		when ?0..?9, ?-
			out = ''
			out << str[poff[0]]
			poff[0] += 1
			float = false
			loop do
				case c = str[poff[0]]
				when ?0..?9
				when ?.
					break if float
					float = true
				# when ?e, ?E	# TODO
				else
					break
				end
				out << c
				poff[0] += 1
			end
			raise ParseError, "JSON: unexpected sequence #{str[poff[0]-1, 4].inspect}" if out == '-'
			float ? out.to_f : out.to_i

		when ?t
			raise ParseError, "JSON: unexpected sequence #{str[poff[0], 4].inspect}" if str[poff[0], 4] != 'true'
			poff[0] += 4
			true
		when ?f
			raise ParseError, "JSON: unexpected sequence #{str[poff[0], 4].inspect}" if str[poff[0], 5] != 'false'
			poff[0] += 5
			false
		when ?n
			raise ParseError, "JSON: unexpected sequence #{str[poff[0], 4].inspect}" if str[poff[0], 4] != 'null'
			poff[0] += 4
			nil
		else
			raise ParseError, "JSON: unexpected sequence #{str[poff[0], 4].inspect}"
		end
	end

private
	SPC = { ?\  => true, ?\t => true, ?\r => true, ?\n => true }
	def self.parse_skipspc(str, poff)
		# TODO comments ?
		poff[0] += 1 while SPC[str[poff[0]]]
	end

	CHR_ESC = { ?b => ?\b, ?f => ?\f, ?n => ?\n, ?r => ?\r, ?t => ?\t, ?" => ?", ?\\ => ?\\, ?/ => ?/ }
	def self.parse_str_escape(str, poff)
		c = str[poff[0]]
		if c == ?u
			poff[0] += 5
			c = str[poff[0]-4, 4].to_i(16)
			c > 255 ? '?' : c
		elsif c = CHR_ESC[c]
			poff[0] += 1
			c
		else
			raise ParseError, "JSON: unexpected escape #{str[poff[0]-1, 4].inspect}"
		end
	end
end

class ::Object ; def to_json ; ::JSON.generate(self) ; end ; end
