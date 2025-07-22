# gemini_chat_ui.gd
extends Control

@onready var message_input = $VBoxContainer/HBoxContainer/MessageInput
@onready var chat_display = $VBoxContainer/ChatDisplay
@onready var send_button = $VBoxContainer/HBoxContainer/SendButton

const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key="
var http_request = HTTPRequest.new()

var chat_history = [] 

# Biến để lưu trữ câu trả lời đầy đủ từ Gemini (CHỈ NỘI DUNG THÔI)
var full_gemini_response_content = "" # Đã đổi tên để dễ phân biệt
# Biến để theo dõi vị trí ký tự hiện tại đang hiển thị
var current_char_index = 0
# Timer để điều khiển tốc độ đánh chữ
var typing_timer = Timer.new()

# Biến để lưu trữ node RichTextLabel của dòng "Thinking..."
var thinking_label_node = null

func _ready():
	add_child(http_request)
	add_child(typing_timer)
	typing_timer.timeout.connect(self._on_typing_timer_timeout)
	typing_timer.wait_time = 0.03 # Tốc độ đánh chữ (0.03 giây mỗi ký tự)

	chat_display.set_use_bbcode(true) 
	
	http_request.request_completed.connect(self._on_http_request_completed)
	send_button.pressed.connect(self._on_send_button_pressed)
	message_input.text_submitted.connect(self._on_send_button_pressed)

func _on_send_button_pressed(text_arg: String = ""):
	var user_message = message_input.text.strip_edges()
	if user_message.is_empty():
		return
	
	# Dừng timer và reset nếu đang chạy từ câu trả lời trước
	typing_timer.stop()
	full_gemini_response_content = "" # Reset nội dung
	current_char_index = 0
	
	# Xóa dòng "Thinking..." cũ nếu có
	if thinking_label_node and thinking_label_node.is_inside_tree():
		thinking_label_node.queue_free()
		thinking_label_node = null
	
	# Thêm màu cho tin nhắn của người dùng: Màu xanh dương nhẹ
	chat_display.append_text("[b][color=#3366CC]You:[/color][/b] " + user_message + "\n")
	message_input.clear()
	
	# --- Bắt đầu phần hiển thị "Thinking..." mới ---
	thinking_label_node = RichTextLabel.new()
	thinking_label_node.set_use_bbcode(true) 
	thinking_label_node.set_text("[b][color=#FF5733]VietarionAI:[/color][/b] [color=gray]Thinking...[/color]")
	thinking_label_node.set_fit_content(true)

	var v_box_container = chat_display.get_parent()
	if v_box_container is VBoxContainer:
		var chat_display_index = v_box_container.get_children().find(chat_display)
		if chat_display_index != -1:
			v_box_container.add_child(thinking_label_node)
			v_box_container.move_child(thinking_label_node, chat_display_index + 1)
		else:
			v_box_container.add_child(thinking_label_node)
	else:
		chat_display.add_child(thinking_label_node)

	chat_display.scroll_to_line(chat_display.get_line_count() - 1)
	# --- Kết thúc phần hiển thị "Thinking..." mới ---
	
	chat_history.append({"role": "user", "parts": [{"text": user_message}]})
	
	print("DEBUG: Sending request for message: ", user_message)
	send_gemini_request()
	
func send_gemini_request():
	var api_key = "ENTER_YOUR_KEY_API_HERE" # Đảm bảo key này đúng 100% nha
	
	var url = GEMINI_API_URL + api_key
	var headers = ["Content-Type: application/json"]
	
	var body = {
		"contents": chat_history 
	}
	
	var body_json = JSON.stringify(body)
	
	print("DEBUG: API URL: ", url)
	print("DEBUG: Request Body (JSON): ", body_json)

	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		chat_display.append_text("[color=red]Error sending request: " + str(error) + "[/color]\n")
		print("DEBUG: HTTP Request Error: ", error)
		
func _on_http_request_completed(result, response_code, headers, body):
	var response_string = body.get_string_from_utf8()
	var json_result = JSON.parse_string(response_string)
	
	print("DEBUG: Response Code: ", response_code)
	print("DEBUG: Raw Response Body: ", response_string)
	
	# Xóa dòng "Thinking..." ngay khi có phản hồi từ API
	if thinking_label_node and thinking_label_node.is_inside_tree():
		thinking_label_node.queue_free()
		thinking_label_node = null
	
	if response_code != 200:
		chat_display.append_text("[color=red]API Error: " + str(response_code) + "\n" + response_string + "[/color]\n")
		return
		
	if json_result and "candidates" in json_result and not json_result.candidates.is_empty():
		var response_text = json_result.candidates[0].content.parts[0].text
		
		# **********************************************
		# CHỖ SỬA LỖI MÀY CẦN CHÚ Ý NHẤT Ở ĐÂY NÈ!
		# **********************************************
		
		# 1. Gán CHỈ NỘI DUNG câu trả lời vào full_gemini_response_content
		full_gemini_response_content = response_text + "\n"
		current_char_index = 0
		
		# 2. Thêm PHẦN MỞ ĐẦU ("VietarionAI:") VỚI BBCODE MỘT LẦN DUY NHẤT
		chat_display.append_text("[b][color=#FF5733]VietarionAI:[/color][/b] ") # Thêm dấu cách cuối cùng cho đẹp

		# Bắt đầu đánh chữ
		typing_timer.start()
		
		# Thêm phản hồi đầy đủ vào lịch sử chat (bao gồm cả tên)
		chat_history.append({"role": "model", "parts": [{"text": "VietarionAI: " + response_text}]})
		
		print("DEBUG: Vietarion Response Text: ", response_text)
	else:
		chat_display.append_text("[color=red]Error: Could not get a response from Gemini.[/color]\n")
		print("DEBUG: No valid response from Vietarion candidates.")

# Hàm này được gọi mỗi khi Timer hết giờ
func _on_typing_timer_timeout():
	# Giờ mình dùng full_gemini_response_content để lấy từng ký tự một
	if current_char_index < full_gemini_response_content.length():
		chat_display.append_text(full_gemini_response_content[current_char_index])
		current_char_index += 1
		chat_display.scroll_to_line(chat_display.get_line_count() - 1)
	else:
		# Dừng timer khi đã hiển thị hết câu
		typing_timer.stop()
		
