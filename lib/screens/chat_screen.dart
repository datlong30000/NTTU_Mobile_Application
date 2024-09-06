import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nienproject/constants/constants.dart';
import 'package:nienproject/providers/chats_provider.dart';
import 'package:nienproject/widgets/chat_widget.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  final String? userId;
  const ChatScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isTyping = false;
  bool _isListening = false;
  bool _isLoading = false;
  bool _showScrollToTopButton = false;
  bool _hasAnimatedTopMessage = false; // Biến trạng thái mới
  late TextEditingController textEditingController;
  late ScrollController _listScrollController;
  late FocusNode focusNode;
  late stt.SpeechToText _speech;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController()
      ..addListener(() {
        setState(() {
          // Hiển thị nút cuộn lên khi người dùng cuộn xuống
          _showScrollToTopButton = _listScrollController.offset > 100;
        });
      });
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    _speech = stt.SpeechToText();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadChatHistory(widget.userId ?? 'default_user_id'));
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> loadChatHistory(String userId) async {
    try {
      await Provider.of<ChatProvider>(context, listen: false)
          .loadChatHistory(userId);

      // Animate tin nhắn trên cùng chỉ nếu nó chưa được animate
      if (!_hasAnimatedTopMessage) {
        _listScrollController.animateTo(
          _listScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        setState(() {
          _hasAnimatedTopMessage = true;
        });
      }
    } catch (error) {
      print("Error loading chat history: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            _stopListeningAndSend();
          }
        },
        onError: (errorNotification) => print('Error: $errorNotification'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) => setState(() {
            _text = result.recognizedWords;
            textEditingController.text = _text;
            if (result.finalResult) {
              _stopListeningAndSend();
            }
          }),
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 3),
          partialResults: true,
        );
      }
    } else {
      _stopListeningAndSend();
    }
  }

  void _stopListeningAndSend() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _isTyping = textEditingController.text.isNotEmpty;
    });
  }

  void _scrollToTop() {
    _listScrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF343541),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => print("Icon menu được nhấn"),
        ),
        title: const Text("NTTU-BOT", style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      return ListView.builder(
  controller: _listScrollController,
  itemCount: chatProvider.getChatList.length,
  reverse: true,
  itemBuilder: (context, index) {
    final chatItem = chatProvider.getChatList[index];
    return Row(
      mainAxisAlignment: chatItem.chatIndex == 1
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (chatItem.chatIndex != 1) SizedBox(width: MediaQuery.of(context).size.width * 0.03),
        Expanded(
          flex: chatItem.chatIndex == 1 ? 9 : 8,
          child: ChatWidget(
            msg: chatItem.msg,
            isFromUser: chatItem.chatIndex == 1,
            shouldAnimate: index == 0,
          ),
        ),
        if (chatItem.chatIndex == 1) SizedBox(width: MediaQuery.of(context).size.width * 0.05),
      ],
    );
  },
);
                    },
                  ),
                ),
                _buildInputField(),
              ],
            ),
            if (_showScrollToTopButton)
              Positioned(
                bottom: 80,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _scrollToTop,
                  backgroundColor: Colors.white,
                  mini: true, // Làm nút nhỏ hơn
                  child: Icon(Icons.arrow_downward_sharp,
                      size: 20), // Thay đổi kích thước icon nếu cần
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Material(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: 120.0,
                ),
                child: TextField(
                  focusNode: focusNode,
                  controller: textEditingController,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Roboto'),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (text) {
                    setState(() {
                      _isTyping = text.trim().isNotEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    fillColor: Colors.white.withOpacity(0.1),
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)),
                    hintText: "Tôi có thể giúp bạn không?",
                    hintStyle:
                        TextStyle(color: Colors.grey, fontFamily: 'Roboto'),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            _isLoading
                ? Container(
                    width:
                        48, // Đảm bảo kích thước ngang đồng bộ với IconButton
                    height: 48, // Đảm bảo kích thước dọc đồng bộ với IconButton
                    alignment: Alignment.center, // Căn giữa loading icon
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, // Độ dày strokeWidth
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_isListening) {
                              _stopListeningAndSend();
                            } else if (_isTyping) {
                              sendMessageFCT(
                                  chatProvider: Provider.of<ChatProvider>(
                                      context,
                                      listen: false));
                            } else {
                              _listen();
                            }
                          },
                    icon: Icon(
                      _isTyping
                          ? Icons.send
                          : (_isListening ? Icons.mic_off : Icons.mic),
                      color: Colors.white,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> sendMessageFCT({required ChatProvider chatProvider}) async {
    if (_isTyping) {
      setState(() {
        _isTyping = false;
        _isListening = false;
        _isLoading = true; // Bắt đầu loading
      });
      try {
        String msg = textEditingController.text;
        chatProvider.addUserMessage(
            msg: msg, userId: widget.userId ?? 'default_user_id');
        textEditingController.clear();
        focusNode.unfocus();
        await chatProvider.sendMessageAndGetAnswers(
          msg: msg,
          userId: widget.userId ?? 'default_user_id',
        );

        await Future.delayed(const Duration(milliseconds: 300));
        if (_listScrollController.position.pixels ==
            _listScrollController.position.maxScrollExtent) {
          _listScrollController.animateTo(
            _listScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } catch (error) {
        print("error $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi kết nối: ${error.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating, // Để SnackBar nổi lên trên
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height - 100,
                right: 20,
                left: 20,
              ),
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false; // Kết thúc loading
        });
      }
    }
  }
}
