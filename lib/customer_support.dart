import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CustomerSupport extends StatefulWidget {
  const CustomerSupport({super.key});

  @override
  State<CustomerSupport> createState() => _CustomerSupportState();
}

class _CustomerSupportState extends State<CustomerSupport> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _ttsReady = false;
  bool _isProcessing = false;
  String _currentInput = '';

  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
    _initializeTts();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text:
            "Hi! I'm your AI customer support assistant. I can help you with questions about orders, menu items, delivery, refunds, and more. How can I assist you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _speakText(
        "Hi! I'm your AI customer support assistant. How can I help you today?");
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (val) => _onSpeechStatus(val),
        onError: (val) => _onSpeechError(val),
      );
      setState(() {});
      debugPrint('Speech recognition initialized: $_speechEnabled');
    } catch (e) {
      debugPrint('Speech initialization error: $e');
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS completed');
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
      });

      setState(() {
        _ttsReady = true;
      });

      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      setState(() {
        _ttsReady = false;
      });
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');
    setState(() {
      _isListening = status == 'listening';
    });

    if (status == 'done' || status == 'notListening') {
      if (_currentInput.isNotEmpty) {
        _processSupportRequest(_currentInput);
        _currentInput = '';
      }
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('Speech error: $error');
    setState(() {
      _isListening = false;
    });
  }

  void _startListening() async {
    if (!_speechEnabled) {
      debugPrint('Speech not enabled, trying to initialize...');
      await _initializeSpeech();
      if (!_speechEnabled) {
        _showError('Speech recognition not available');
        return;
      }
    }

    if (_isListening) {
      debugPrint('Already listening, stopping...');
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      return;
    }

    setState(() {
      _currentInput = '';
    });

    debugPrint('Starting to listen...');
    try {
      await _speech.listen(
        onResult: (val) => setState(() {
          _currentInput = val.recognizedWords;
        }),
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _showError('Failed to start speech recognition');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _speakText(String text) async {
    if (!_ttsReady) {
      debugPrint('TTS not ready, skipping speech: $text');
      return;
    }

    try {
      debugPrint('Speaking: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
      await _initializeTts();
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _textController.clear();
      _processSupportRequest(text);
    }
  }

  void _processSupportRequest(String userInput) async {
    if (userInput.isEmpty) return;

    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(
        text: userInput,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessing = true;
    });

    _scrollToBottom();

    try {
      final aiResponse = await _getAIResponse(userInput);

      // Add AI response to chat
      setState(() {
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
      });

      _scrollToBottom();
      await _speakText(aiResponse);
    } catch (e) {
      debugPrint('Error processing support request: $e');
      setState(() {
        _messages.add(ChatMessage(
          text:
              "I'm sorry, I'm having trouble connecting right now. Please try again in a moment.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _getAIResponse(String userInput) async {
    final prompt = """
You are a helpful customer support AI assistant for a food delivery app called "AI Food Delivery". 

Your role is to:
1. Answer questions about food orders, menu items, delivery, payments, and app features
2. Help resolve customer issues and complaints
3. Provide information about restaurant policies
4. Guide customers through the ordering process
5. Handle refund requests and technical issues

IMPORTANT GUIDELINES:
- Be friendly, professional, and empathetic
- Keep responses concise but helpful (2-3 sentences max)
- If you don't know specific company policies, provide general helpful advice
- For complex issues, suggest contacting human support
- Always try to solve the customer's problem

CUSTOMER MESSAGE: "$userInput"

Respond as a helpful customer support representative:""";

    try {
      final requestBody = {
        "model": "gpt-3.5-turbo",
        "messages": [
          {
            "role": "system",
            "content":
                "You are a helpful customer support AI assistant for a food delivery app. Be concise, friendly, and solution-focused."
          },
          {"role": "user", "content": prompt}
        ],
        "max_tokens": 150,
        "temperature": 0.7,
      };

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['OPENAI_API_KEY']}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        debugPrint('AI API Error: ${response.statusCode} - ${response.body}');
        return "I'm sorry, I'm having trouble connecting to our support system right now. Please try again in a moment.";
      }
    } catch (e) {
      debugPrint('Error calling AI API: $e');
      return "I'm experiencing technical difficulties. Please try again shortly.";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _addWelcomeMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Support'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicators
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _speechEnabled && _ttsReady
                  ? Colors.green[50]
                  : Colors.orange[50],
              border: Border(
                bottom: BorderSide(
                  color: _speechEnabled && _ttsReady
                      ? Colors.green
                      : Colors.orange,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _speechEnabled && _ttsReady
                      ? Icons.check_circle
                      : Icons.warning,
                  size: 16,
                  color: _speechEnabled && _ttsReady
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _speechEnabled && _ttsReady
                      ? 'Voice Support Ready'
                      : 'Voice Support Limited',
                  style: TextStyle(
                    fontSize: 12,
                    color: _speechEnabled && _ttsReady
                        ? Colors.green[800]
                        : Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isProcessing) {
                  return const ChatBubble(
                    text: "AI is thinking...",
                    isUser: false,
                    isTyping: true,
                  );
                }

                final message = _messages[index];
                return ChatBubble(
                  text: message.text,
                  isUser: message.isUser,
                  timestamp: message.timestamp,
                );
              },
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Voice input status
                if (_isListening)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentInput.isEmpty
                                ? 'Listening...'
                                : 'You said: "$_currentInput"',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Input row
                Row(
                  children: [
                    // Voice button
                    IconButton(
                      onPressed: _speechEnabled ? _startListening : null,
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: _speechEnabled
                            ? (_isListening ? Colors.red : Colors.blue)
                            : Colors.grey,
                      ),
                      tooltip:
                          _isListening ? 'Stop Listening' : 'Start Voice Input',
                    ),

                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Type your question or concern...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendTextMessage(),
                        enabled: !_isProcessing,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send button
                    IconButton(
                      onPressed: _isProcessing ? null : _sendTextMessage,
                      icon: Icon(
                        Icons.send,
                        color: _isProcessing ? Colors.grey : Colors.blue,
                      ),
                      tooltip: 'Send Message',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// Chat bubble widget
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime? timestamp;
  final bool isTyping;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.timestamp,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[600],
              child: const Icon(Icons.support_agent,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue[600] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isTyping
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[600]!,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              text,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                ),
                if (timestamp != null && !isTyping)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}
