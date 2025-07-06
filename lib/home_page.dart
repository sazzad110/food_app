import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'cart_provider.dart';
import 'customer_support.dart';
import 'menu_item.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _ttsReady = false;
  String _speechText = '';
  String _lastWords = '';

  // Enhanced menu with categories and tags
  final List<MenuItem> _menu = [
    // Burgers
    MenuItem('Classic Beef Burger', ['beef', 'burger', 'classic', 'meat'],
        'burger', false),
    MenuItem('Spicy Beef Burger', ['beef', 'burger', 'spicy', 'hot', 'meat'],
        'burger', true),
    MenuItem(
        'Chicken Burger', ['chicken', 'burger', 'poultry'], 'burger', false),
    MenuItem('Spicy Chicken Burger',
        ['chicken', 'burger', 'spicy', 'hot', 'poultry'], 'burger', true),

    // Pizzas
    MenuItem('Margherita Pizza', ['pizza', 'margherita', 'cheese', 'tomato'],
        'pizza', false),
    MenuItem('Pepperoni Pizza', ['pizza', 'pepperoni', 'meat', 'sausage'],
        'pizza', false),
    MenuItem('Spicy Mexican Pizza',
        ['pizza', 'mexican', 'spicy', 'hot', 'jalapeño'], 'pizza', true),
    MenuItem('BBQ Chicken Pizza',
        ['pizza', 'bbq', 'chicken', 'barbecue', 'poultry'], 'pizza', false),

    // Wraps
    MenuItem('Veggie Wrap', ['veggie', 'wrap', 'vegetable', 'veg', 'healthy'],
        'wrap', false),
    MenuItem(
        'Spicy Veggie Wrap',
        ['veggie', 'wrap', 'vegetable', 'spicy', 'hot', 'healthy'],
        'wrap',
        true),
    MenuItem('Chicken Caesar Wrap', ['chicken', 'wrap', 'caesar', 'poultry'],
        'wrap', false),
    MenuItem('Beef Fajita Wrap', ['beef', 'wrap', 'fajita', 'mexican', 'meat'],
        'wrap', false),

    // Sides
    MenuItem('Spicy Wings', ['wings', 'chicken', 'spicy', 'hot', 'buffalo'],
        'sides', true),
    MenuItem('Loaded Nachos', ['nachos', 'cheese', 'mexican', 'chips'], 'sides',
        false),
    MenuItem('Spicy Fries', ['fries', 'potato', 'spicy', 'hot'], 'sides', true),

    // Drinks
    MenuItem('Coke', ['coke', 'cola', 'drink', 'soda'], 'drink', false),
    MenuItem(
        'Orange Juice',
        ['orange', 'juice', 'drink', 'fresh', 'flavour', 'flavor'],
        'drink',
        false),
    MenuItem('Water', ['water', 'drink', 'plain'], 'drink', false),
    MenuItem(
        'Sprite', ['sprite', 'lemon', 'lime', 'drink', 'soda'], 'drink', false),
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeSpeech();
    _initializeTts();
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
      // Initialize TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Set completion handler
      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS completed');
      });

      // Set error handler
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
      });

      // Test TTS availability
      var engines = await _flutterTts.getEngines;
      debugPrint('Available TTS engines: $engines');

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
      if (_speechText.isNotEmpty) {
        _processSpeech(_speechText);
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
      _speechText = '';
      _lastWords = '';
    });

    debugPrint('Starting to listen...');
    try {
      await _speech.listen(
        onResult: (val) => setState(() {
          _speechText = val.recognizedWords;
          if (val.hasConfidenceRating && val.confidence > 0) {
            _lastWords = val.recognizedWords;
          }
        }),
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) => debugPrint('Sound level: $level'),
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
      // Reinitialize TTS on error
      await _initializeTts();
    }
  }

  void _processSpeech(String text) async {
    if (text.isEmpty) return;

    debugPrint('Processing speech with AI: "$text"');
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Show processing status
    setState(() {
      _speechText = '🤖 AI is analyzing your request...';
    });

    await _speakText("Let me find what you're looking for");

    // Process everything through AI
    await _processWithAI(text, cart);
  }

  // AI processing for all requests
  Future<void> _processWithAI(String text, CartProvider cart) async {
    // Create detailed menu description for AI
    String detailedMenu = _menu.map((item) {
      String spicyInfo = item.isSpicy ? " (SPICY)" : " (NOT SPICY)";
      String keywords = item.keywords.join(", ");
      return "${item.name}$spicyInfo - Category: ${item.category} - Keywords: $keywords";
    }).join("\n");

    final prompt = """
You are a food ordering AI assistant. Your job is to analyze customer requests and select the BEST matching item from the available menu.

CUSTOMER REQUEST: "$text"

AVAILABLE MENU ITEMS:
$detailedMenu

DETAILED INSTRUCTIONS:

1. MENU REQUESTS:
   If customer says ANY of these phrases, respond with "SHOW_MENU":
   - "show menu" / "see menu" / "what's on the menu"
   - "what do you have" / "what's available" / "what can I get"
   - "menu please" / "show me options" / "list items"
   - "what food do you have" / "what's there"

2. SPICY FOOD REQUESTS:
   If customer mentions "spicy", "hot", "heat", "jalapeño", "pepper", "fire", "burn":
   - ONLY select items marked with "(SPICY)"
   - Choose the BEST spicy item that matches their other preferences
   - Examples: "something spicy" → pick any spicy item, "spicy burger" → "Spicy Beef Burger"

3. SPECIFIC FOOD TYPE REQUESTS:
   - "beef" / "meat" → prioritize beef items
   - "chicken" / "poultry" → prioritize chicken items  
   - "pizza" → any pizza item
   - "burger" → any burger item
   - "wrap" → any wrap item
   - "drink" / "beverage" → any drink item
   - "side" / "sides" → any sides item
   - "veggie" / "vegetable" / "veg" → vegetarian items

4. FLAVOR/INGREDIENT REQUESTS:
   - "orange" → Orange Juice
   - "cola" / "coke" → Coke
   - "cheese" → items with cheese
   - "bbq" / "barbecue" → BBQ items
   - "mexican" → Mexican-style items

5. MULTIPLE ITEMS:
   If customer mentions multiple items with "and" or commas:
   - Select ONLY the FIRST item mentioned
   - Example: "burger and fries" → select burger only

6. VAGUE REQUESTS:
   - "something good" → select most popular category item
   - "food" → select a main dish (burger/pizza/wrap)
   - "anything" → select Classic Beef Burger as default

7. NO MATCH:
   Only respond "NO_MATCH" if:
   - Request is completely unrelated to food
   - Customer asks for items not on menu
   - Request is unclear and doesn't fit any category

RESPONSE RULES:
- Respond with EXACTLY the item name as written in the menu
- NO quotation marks around the item name
- NO explanations, descriptions, or extra words
- NO suggestions or alternatives
- ONLY respond with: [Exact Item Name] OR "SHOW_MENU" OR "NO_MATCH"

EXAMPLES:
- "I want something spicy" → Spicy Beef Burger
- "get me a drink" → Coke  
- "chicken please" → Chicken Burger
- "show me what you have" → SHOW_MENU
- "pizza with spice" → Spicy Mexican Pizza
- "I want a car" → NO_MATCH

Your response:""";

    debugPrint('Sending prompt to AI: $prompt');

    try {
      final requestBody = {
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": prompt}
        ],
        "max_tokens": 50,
        "temperature": 0.1,
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
        final aiReply = data['choices'][0]['message']['content'].trim();

        debugPrint('AI Response: "$aiReply"');

        if (aiReply == "SHOW_MENU") {
          await _handleMenuRequest();
          return;
        }

        if (aiReply == "NO_MATCH") {
          await _handleNoMatch(text);
          return;
        }

        // Find exact match in menu
        MenuItem? foundItem = _menu.firstWhere(
          (item) => item.name.toLowerCase() == aiReply.toLowerCase(),
          orElse: () =>
              MenuItem('', [], '', false), // Return dummy item if not found
        );

        if (foundItem.name.isNotEmpty) {
          cart.addToCart(foundItem);
          String spicyNote = foundItem.isSpicy ? " This is a spicy item!" : "";
          await _speakText(
              "Perfect! I've added ${foundItem.name} to your cart.$spicyNote");
          setState(() {
            _speechText =
                '✅ AI Selected: ${foundItem.name}${foundItem.isSpicy ? ' 🌶️' : ''}';
          });
        } else {
          debugPrint('AI returned item not found in menu: $aiReply');
          await _handleNoMatch(text);
        }
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        await _handleAPIError();
      }
    } catch (e) {
      debugPrint('Error calling OpenAI API: $e');
      await _handleAPIError();
    }
  }

  Future<void> _handleMenuRequest() async {
    String menuByCategory = '';

    // Group items by category
    Map<String, List<MenuItem>> categorized = {};
    for (MenuItem item in _menu) {
      categorized.putIfAbsent(item.category, () => []).add(item);
    }

    categorized.forEach((category, items) => {
          menuByCategory +=
              '${category.toUpperCase()}: ${items.map((e) => "${e.name}${e.isSpicy ? ' (spicy)' : ''}").join(', ')}. '
        });

    await _speakText(
        "Here's our menu: $menuByCategory What would you like to order?");
    setState(() {
      _speechText = '📋 Menu displayed - What would you like?';
    });
  }

  Future<void> _handleNoMatch(String text) async {
    await _speakText(
        "I couldn't find a good match for '$text'. Try asking for something spicy, a specific type of food like beef burger or chicken pizza, or say 'show me the menu' to see all options.");
    setState(() {
      _speechText =
          '❓ No match found. Try: "something spicy", "beef burger", "show menu"';
    });
  }

  Future<void> _handleAPIError() async {
    await _speakText(
        "Sorry, I'm having trouble connecting to my AI brain right now. Please try again in a moment.");
    setState(() {
      _speechText = '❌ AI connection error. Please try again.';
    });
  }

  void _openCustomerSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerSupport(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Food Delivery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: _openCustomerSupport,
            tooltip: 'Customer Support',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Speech & TTS Status Indicators
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _speechEnabled && _ttsReady
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _speechEnabled && _ttsReady ? Colors.green : Colors.red,
                ),
              ),
              child: Column(children: [
                Row(
                  children: [
                    Icon(
                      _speechEnabled ? Icons.check_circle : Icons.error,
                      color: _speechEnabled ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _speechEnabled
                          ? 'Speech Recognition Ready'
                          : 'Speech Recognition Not Available',
                      style: TextStyle(
                        color: _speechEnabled
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _ttsReady ? Icons.volume_up : Icons.volume_off,
                      color: _ttsReady ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _ttsReady
                          ? 'Text-to-Speech Ready'
                          : 'Text-to-Speech Not Available',
                      style: TextStyle(
                        color: _ttsReady ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // AI-Powered Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'AI-Powered Food Selection',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🤖 Just tell me what you want! Try: "I want something spicy", "Give me a beef item", "I need a drink with orange flavor", "Show me the menu"',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Speech Button
            ElevatedButton.icon(
              onPressed: _speechEnabled ? _startListening : null,
              icon: Icon(_isListening ? Icons.hearing : Icons.mic),
              label:
                  Text(_isListening ? 'Listening...' : 'Talk to AI Assistant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Speech Text Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _speechText.isEmpty
                    ? 'Your speech will appear here...'
                    : _speechText.startsWith('🤖') ||
                            _speechText.startsWith('✅') ||
                            _speechText.startsWith('❌') ||
                            _speechText.startsWith('💬') ||
                            _speechText.startsWith('❓') ||
                            _speechText.startsWith('📋')
                        ? _speechText
                        : 'You said: "$_speechText"',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),

            const Divider(),
            const Text('Menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Menu Items by Category
            ..._buildMenuByCategory(),

            const SizedBox(height: 20),
            const Divider(),
            const Text('Cart',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Cart Items
            if (cart.cartItems.isEmpty)
              const Text('Your cart is empty - Ask AI to add items!')
            else
              ...cart.cartItems.map((item) => Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                          '${item.category} ${item.isSpicy ? '🌶️ Spicy' : ''}'),
                      leading: const Icon(Icons.shopping_cart),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          cart.removeFromCart(item);
                        },
                      ),
                    ),
                  )),

            // Clear Cart Button
            if (cart.cartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    cart.clearCart();
                    _speakText("Cart cleared");
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Cart'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMenuByCategory() {
    Map<String, List<MenuItem>> categorized = {};
    for (MenuItem item in _menu) {
      categorized.putIfAbsent(item.category, () => []).add(item);
    }

    List<Widget> widgets = [];
    categorized.forEach((category, items) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange),
          ),
        ),
      );
      widgets.addAll(items.map((item) => Card(
            child: ListTile(
              title: Row(
                children: [
                  Expanded(child: Text(item.name)),
                  if (item.isSpicy)
                    const Text('🌶️', style: TextStyle(fontSize: 16)),
                ],
              ),
              subtitle: Text(item.keywords.take(3).join(', ')),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  Provider.of<CartProvider>(context, listen: false)
                      .addToCart(item);
                  await _speakText("${item.name} has been added to your cart");
                },
              ),
            ),
          )));
    });

    return widgets;
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }
}
