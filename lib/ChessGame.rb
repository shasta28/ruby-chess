require "./lib/ChessBoard"
require "./lib/ChessPiece"
require "./lib/ChessPlayer"
require "./lib/FileManager"
include FileManager
require "./lib/Help"
include Help

class ChessGame

	attr_accessor :active
	attr_reader :board, :players, :white_set, :black_set

	def initialize(player1="White",player2="Black")

		@players = [ChessPlayer.new(player1,:white), ChessPlayer.new(player2,:black)]
		@board = ChessBoard.new

		@white_set = []
		@black_set = []

		8.times do
			@white_set << Pawn.new(:white)
			@black_set << Pawn.new(:black)
		end
		2.times do
			@white_set << Rook.new(:white)
			@white_set << Knight.new(:white)
			@white_set << Bishop.new(:white)
			@black_set << Rook.new(:black)
			@black_set << Knight.new(:black)
			@black_set << Bishop.new(:black)
		end
		@white_set << Queen.new(:white)
		@white_set << King.new(:white)
		@black_set << Queen.new(:black)
		@black_set << King.new(:black)

		@players[0].set = @white_set
		@players[1].set = @black_set

		reset_board

		@winner = nil
		@active = @players[0]

	end


	def reset_board

		#sort sets alphabecially
		@white_set.sort_by! { |piece| piece.class.to_s }
		@black_set.sort_by! { |piece| piece.class.to_s }

		#bishops
		@white_set[0].coord = @board.square(3,1)
		@white_set[1].coord = @board.square(6,1)
		@black_set[0].coord = @board.square(3,8)
		@black_set[1].coord = @board.square(6,8)

		#king
		@white_set[2].coord = @board.square(5,1)
		@black_set[2].coord = @board.square(5,8)

		#knights
		@white_set[3].coord = @board.square(2,1)
		@white_set[4].coord = @board.square(7,1)
		@black_set[3].coord = @board.square(2,8)
		@black_set[4].coord = @board.square(7,8)

		#pawns
		@white_set[5..12].each_with_index { |pawn,i| pawn.coord = @board.square(i-4,2); pawn.demote; }
		@black_set[5..12].each_with_index { |pawn,i| pawn.coord = @board.square(i-4,7); pawn.demote; }

		#queen
		@white_set[13].coord = @board.square(4,1)
		@black_set[13].coord = @board.square(4,8)

		#rooks
		@white_set[14].coord = @board.square(1,1)
		@white_set[15].coord = @board.square(8,1)
		@black_set[14].coord = @board.square(1,8)
		@black_set[15].coord = @board.square(8,8)

		@white_set.each { |piece| piece.captured = false; }
		@black_set.each { |piece| piece.captured = false; }

	end


	def opponent(player=@active)
		@players[@players.index(player)-1]
	end

	#main gameplay loop
	def play
		board.draw
		until gameover? do
			input = Readline.readline("#{@active.name}: ")
			until handle_input(input) do
				input = Readline.readline("#{@active.name}: ")
			end

			break if input.downcase == "exit"
			board.draw if input.downcase != "resign"

			@active = opponent
			puts "#{@active.name} is in check!" if check? && !checkmate?
			request_draw if opponent.draw
		end
		print_results
	end

	#output endgame results
	def print_results
		if checkmate?
			puts "Checkmate!"
			@winner = opponent
		else
			puts "Stalemate! #{@active.name} has no moves." if stalemate?
			puts "The game is a draw!" if draw? || stalemate?
		end
		puts "#{@winner.name} wins!" if @winner
	end


	#process possible user input; returns true only after a complete move
	def handle_input(input)
		case input.downcase
			when "save", /^save\s\w+$/
				file = input.split[1]
				FileManager.save_game(self,file)
				return false

			when "show saves"
				puts "\n***Saved Games***"
				FileManager.list_saves
				puts "***End***"
				return false

			when /^[pkqrnb][a-h]?[1-8]?x?[a-h][1-8]/
				m = decode_move(input)
				move(m[:piece],m[:x2],m[:y2],m[:x1],m[:y1])

			when "o-o", "0-0"
				castle_ks

			when "o-o-o", "0-0-0"
				castle_qs

			when "resign"
				resign(@active)
				return true

			when "draw"
				@active.draw = true
				puts "You have requested a draw. Make one last move: "
				return false

			when "help"
				Help.help
				@board.draw
				return false

			when "exit"
				puts "Exiting game..."
				return true

			when "quit"
				puts "Goodbye!"
				exit

			when "get ye flask"
				puts "You cannot get ye flask."
				return false

			else
				puts "Invalid input. Enter [help] for commands."
				return false
		end
	end


	def resign(player)
		@winner = @players.select { |p| p != player }.shift
		puts "#{player.name} has resigned!"
	end


	def gameover?
		checkmate? || stalemate? || draw? || @winner
	end

	#player is in check with no moves available
	def checkmate?(player=@active)
		in_play = player.set.select { |p| p.in_play? }
		check?(player) && in_play.all? { |p| get_moves(p).empty?  }
	end

	#player is not in check but has no moves available
	def stalemate?(player=@active)
		in_play = player.set.select { |p| p.in_play? }
		in_play.all? { |p| get_moves(p).empty? } && !check?(player)
	end


	def draw?
		@players.all? { |p| p.draw }
	end

	def request_draw
		puts "#{opponent.name} has request a draw."
		input = Readline.readline("#{@active.name}, agree to a draw? ").downcase
		until input=="y" || input=="yes" || input=="n" || input=="no" do
			input = Readline.readline("#{@active.name}, agree to a draw? Yes or no: ").downcase
		end
		if (input == "y" || input == "yes")
			@active.draw = true
		else
			puts "Draw rejected."
			opponent.draw = false
		end
	end


	#get possible moves of piece from given origin (or piece's origin if ox,oy not specified)
	def get_moves(piece,ox=nil, oy=nil)
		moves = [] 

		return moves if !piece.coord && !ox && !oy
		ox = piece.coord.x if !ox
		oy = piece.coord.y if !oy

		#pawn
		if (piece.name == "P")
			case piece.color
				when :white
					moves << [ox,oy+2] if piece.coord.y == 2 && !@board.square(ox,oy+2).occupant && !@board.square(ox,oy+1).occupant
					moves << [ox,oy+1] if oy+1 <= 8 && !@board.square(ox,oy+1).occupant
					diags = [[ox+1, oy+1], [ox-1, oy+1]]
					diags.each { |d| moves << d if d[0].between?(1,8) && d[1].between?(1,8) && @board.square(d[0],d[1]).alignment == :black }
				when :black
					moves << [ox,oy-2] if piece.coord.y == 7 && !@board.square(ox,oy-2).occupant && !@board.square(ox,oy-1).occupant
					moves << [ox,oy-1] if oy-1 > 0 && !@board.square(ox,oy-1).occupant
					diags = [[ox-1, oy-1], [ox+1, oy-1]]
					diags.each { |d| moves << d if d[0].between?(1,8) && d[1].between?(1,8) && @board.square(d[0],d[1]).alignment == :white }
			end
			en_passant(piece, ox, oy).each { |m| moves << m }
	 	
		#knight				
		elsif (piece.name == "N")
			next_sq = [
				[ox-2, oy+1],
				[ox-1, oy+2],
				[ox+1, oy+2],
				[ox+2, oy+1],
				[ox+2, oy-1],
				[ox+1, oy-2],
				[ox-2, oy-1],
				[ox-1, oy-2]
			]
			next_sq.each { |sq|  moves << sq if sq[0].between?(1,8) && sq[1].between?(1,8) && @board.square(sq[0],sq[1]).alignment != piece.color }		

		#king
		elsif (piece.name == "K")
			next_sq = [
				[ox+1, oy],
				[ox-1, oy],
				[ox, oy+1],
				[ox, oy-1],
				[ox+1, oy+1],
				[ox-1, oy-1],
				[ox+1, oy-1],
				[ox-1, oy+1]
			]
			next_sq.each { |sq|  moves << sq if sq[0].between?(1,8) && sq[1].between?(1,8) && @board.square(sq[0],sq[1]).alignment != piece.color }

		else

			#orthagonal moves (rook or queen)
			if (piece.name == "R" || piece.name == "Q")
				(ox+1).upto(8) do |nx|
					moves << [nx,oy] if @board.square(nx,oy).alignment != piece.color
					break if @board.square(nx,oy).occupant
				end
				(ox-1).downto(1) do |nx|
					moves << [nx,oy] if @board.square(nx,oy).alignment != piece.color
					break if @board.square(nx,oy).occupant
				end
				(oy+1).upto(8) do |ny|
					moves << [ox,ny] if @board.square(ox,ny).alignment != piece.color
					break if @board.square(ox,ny).occupant
				end
				(oy-1).downto(1) do |ny|
					moves << [ox,ny] if @board.square(ox,ny).alignment != piece.color
					break if @board.square(ox,ny).occupant
				end
			end

			#diagonal moves (bishop or queen)
			if (piece.name == "B" || piece.name == "Q")
				nx, ny = ox, oy
				while nx < 8 && ny < 8 do
					nx += 1
					ny += 1
					moves << [nx, ny] if @board.square(nx,ny).alignment != piece.color
					break if @board.square(nx,ny).occupant
				end
				nx, ny = ox, oy
				while nx > 1 && ny > 1 do
					nx -= 1
					ny -= 1
					moves << [nx, ny] if @board.square(nx,ny).alignment != piece.color
					break if @board.square(nx,ny).occupant
				end
				nx, ny = ox, oy
				while nx > 1 && ny < 8 do
					nx -= 1
					ny += 1
					moves << [nx, ny] if @board.square(nx,ny).alignment != piece.color
					break if @board.square(nx,ny).occupant
				end
				nx, ny = ox, oy
				while nx < 8 && ny > 1 do
					nx += 1
					ny -= 1
					moves << [nx, ny] if @board.square(nx,ny).alignment != piece.color
					break if @board.square(nx,ny).occupant
				end
			end
		end

		#prevent active player from moving into check
		moves.select! { |m| !vulnerable_move?(piece,m[0],m[1]) } if piece.color == @active.color

		if (ox == piece.coord.x && oy == piece.coord.y)
			piece.moves = moves
		else
			moves
		end

	end


	#enable en passant capture if pawn is adjacent to enemy pawn that has just opened with a double step
	def en_passant(piece,x,y)
		passant_moves = []
		if piece.color == :white && y == 5
			passant_moves << [x-1, y+1] if x-1 > 0 && @board.square(x-1, y).alignment == :black && @board.square(x-1, y).occupant.name == "P" && @board.square(x-1, y).occupant.passant_defensive && !@board.square(x-1, y+1).occupant
			passant_moves << [x+1, y+1] if x+1 <= 8 && @board.square(x+1, y).alignment == :black && @board.square(x+1, y).occupant.name == "P" && @board.square(x+1, y).occupant.passant_defensive && !@board.square(x+1, y+1).occupant
		elsif piece.color == :black && y == 4
			passant_moves << [x-1, y-1] if x-1 > 0 && @board.square(x-1, y).alignment == :white && @board.square(x-1, y).occupant.name == "P" && @board.square(x-1, y).occupant.passant_defensive && !@board.square(x-1, y-1).occupant
			passant_moves << [x+1, y-1] if x+1 <= 8 && @board.square(x+1, y).alignment == :white && @board.square(x+1, y).occupant.name == "P" && @board.square(x+1, y).occupant.passant_defensive && !@board.square(x+1, y-1).occupant
		end
		piece.passant_offensive = true if !passant_moves.empty? && piece.color == @active.color
		passant_moves
	end


	#process chess notation
	def decode_move(input)
		input = input.tr("x","").split(//) #capture notation "x" is optional
		move = {}
		move[:piece] = input.shift.upcase #first character is piece name
		move[:x1] = nil
		move[:y1] = nil
		if ( input.length == 4 ) #e.g. g1f3
			move[:x1] = ChessBoard::CHAR_RANGE.index(input.shift.downcase)+1
			move[:y1] = input.shift.to_i
		elsif ( input.length == 3 )  #e.g. gf3
			if input[0].to_i > 0
				move[:y1] = input.shift.to_i
			else
				move[:x1] = ChessBoard::CHAR_RANGE.index(input.shift.downcase)+1
			end
		end
		move[:x2] = ChessBoard::CHAR_RANGE.index(input.shift.downcase)+1
		move[:y2] = input.shift.to_i
		move
	end

	#move piece from (x1,y1) to (x2,y2) according to game rules
	def move(piece,x2,y2,x1=nil,y1=nil)
		movable = @active.set.select { |p| p.name == piece && !p.captured } #get pieces that haven't been captured
		movable.each { |p| get_moves(p) } #see what moves each piece has
		movable.select! { |p| p.moves.include?([x2,y2]) } #select pieces that include designated coordinates
		movable.select! { |p| p.coord.x == x1 } if x1 #disambiguate if file given
		movable.select! { |p| p.coord.y == y1 } if y1 #disambiguate if rank given
		if ( movable.size > 1 )
			puts "Ambiguous command! Multiple #{ChessPiece::CODEX[piece.upcase]}s can move to #{ChessBoard::CHAR_RANGE[x2-1]}#{y2}."
			return false
		elsif ( movable.size == 0 )
			puts "Illegal move!"
			return false
		else
			toggle_passant(movable[0],x2,y2) if movable[0].name == "P" #check for en passant
			@board.square(x2,y2).occupant.captured = true if @board.square(x2,y2).occupant #capture piece if destination is occupied
			movable[0].coord = @board.square(x2,y2) #move the piece
			promotion_check(movable[0]) if movable[0].name == "P" #check for pawn promotion
			movable[0].castle = false if movable[0].class.to_s == "King" || movable[0].class.to_s == "Rook" #disallow castling if rook/king moved
			return true
		end
	end

	#promote pawn if it has reached opposite rank
	def promotion_check(pawn)
		if ( (pawn.color == :white && pawn.coord.y == 8) || (pawn.color == :black && pawn.coord.y == 1) )
			puts "#{@active.name}..."
			pawn.promote
		end		
	end


	def toggle_passant(pawn,x,y)
		#execute en passant capture if able
		if (pawn.passant_offensive)
			case x
				when pawn.coord.x+1
					@board.square(x,pawn.coord.y).occupant.captured = true
					@board.square(x,pawn.coord.y).occupant = nil
				when pawn.coord.x-1
					@board.square(x,pawn.coord.y).occupant.captured = true
					@board.square(x,pawn.coord.y).occupant = nil
			end
		else
			#if pawn's first move is two spaces, it's open to en passant attack
			case pawn.color
				when :white
					pawn.passant_defensive = true if pawn.coord.y == 2 && y == 4
				when :black
					pawn.passant_defensive = true if pawn.coord.y == 7 && y == 5 
			end
		end
		#unexecuted en passant is forfiet on next move
		pawns = opponent.set.select { |p| p.name == "P" && p.in_play? }
		pawns.each { |p| p.passant_defensive = false; p.passant_offensive = false; }
	end


	#player is in check if any opponent piece can move to the king's coordinates
	def check?(player=@active)
		king = player.set.select { |p| p.name == "K"}.first
		opponent(player).set.each do |piece|
			if ( piece.in_play? )
				get_moves(piece)
				if (piece.moves.include? [king.coord.x, king.coord.y])
					return true
				end
			end
		end
		return false
	end


	#will hypothetical move of piece to (x,y) leave king vulnerable?
	def vulnerable_move?(piece,x,y)
		origin = piece.coord
		dest = @board.square(x,y)
		captive = dest.occupant
		player = @players.select { |p| p.color == piece.color }.first

		piece.coord = dest
		vulnerable = check?(player)

		#reset hypothetical move
		piece.coord = origin
		captive.coord = dest if captive

		vulnerable
	end

	#castle kingside
	def castle_ks(player=@active)
		king = player.set.select { |p| p.name == "K" && p.castle }.first
		rook = player.set.select { |p| p.name == "R" && p.castle && p.in_play? && p.coord.x == 8 }.first
		if (check?(player) || !king || !rook)
			puts "Illegal move!"
			return false
		end
		y = king.coord.y
		path = [[7,y], [6,y]]
		if (path.any? { |sq| vulnerable_move?(king,sq[0],sq[1]) || @board.square(sq[0],sq[1]).occupant })
			puts "Illegal move!"
			return false
		else
			king.coord = @board.square(7,y)
			rook.coord = @board.square(6,y)
			king.castle = false
			rook.castle = false
			return true
		end
	end

	#castle queenside
	def castle_qs(player=@active)
		king = player.set.select { |p| p.name == "K" && p.castle }.first
		rook = player.set.select { |p| p.name == "R" && p.castle && p.in_play? && p.coord.x == 1 }.first
		if (check?(player) || !king || !rook)
			puts "Illegal move!"
			return false
		end
		y = king.coord.y
		path = [[2,y], [3,y], [4,y]]
		if (path.any? { |sq| @board.square(sq[0],sq[1]).occupant } || path[1..-1].any? { |sq| vulnerable_move?(king,sq[0],sq[1]) })
			puts "Illegal move!"
			return false
		else
			king.coord = @board.square(3,y)
			rook.coord = @board.square(4,y)
			king.castle = false
			rook.castle = false
			return true
		end
	end


end