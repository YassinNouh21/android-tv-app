import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

enum KeyboardType {
  numeric,
  alphanumeric,
}

class KeyboardCustom extends StatefulWidget {
  const KeyboardCustom({
    Key? key,
    this.keyboardType = KeyboardType.alphanumeric,
    required this.controller,
    required this.applyMask,
    this.fontColor = const Color(0xffDADCE0),
    this.iconColor = Colors.white,
    this.buttonColor = const Color(0xff2A3139),
    this.backgroundColor = const Color(0xff191C22),
    this.onSubmit,
  }) : super(key: key);
  final void Function(String)? onSubmit;

  final KeyboardType keyboardType;
  final TextEditingController controller;
  final String Function(String) applyMask;
  final Color fontColor;
  final Color iconColor;
  final Color buttonColor;
  final Color backgroundColor;

  @override
  State<KeyboardCustom> createState() => _KeyboardCustomState();
}

class _KeyboardCustomState extends State<KeyboardCustom> {
  bool _shiftEnabled = false;
  bool _isArabic = false;
  late Timer _backspaceTimer;
  late LongPressGestureRecognizer _backspaceLongPressRecognizer;

  @override
  void initState() {
    super.initState();
    _backspaceTimer = Timer(Duration.zero, () {});
    _backspaceLongPressRecognizer = LongPressGestureRecognizer()
      ..onLongPressStart = _startBackspaceTimer
      ..onLongPressEnd = _stopBackspaceTimer;
  }

  @override
  void dispose() {
    _backspaceTimer.cancel();
    _backspaceLongPressRecognizer.dispose();
    super.dispose();
  }

  void _startBackspaceTimer(LongPressStartDetails details) {
    _backspaceTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (widget.controller.text.isEmpty) {
        timer.cancel();
        return;
      }
      final newText = widget.controller.text.substring(0, widget.controller.text.length - 1);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    });
  }

  void _stopBackspaceTimer(LongPressEndDetails details) {
    _backspaceTimer.cancel();
  }

  Widget buildButton(String tecla) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fontSize = (constraints.maxHeight * 0.45).clamp(12.0, 48.0);
          return ElevatedButton(
            onPressed: () {
              final String valorAtual = widget.controller.text;
              final String valorNovo = _shiftEnabled ? tecla.toUpperCase() : tecla.toLowerCase();
              final String newText = widget.applyMask(valorAtual + valorNovo);
              widget.controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
              if (_shiftEnabled) {
                setState(() {
                  _shiftEnabled = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade300,
              disabledBackgroundColor: Colors.grey.shade400,
              backgroundColor: widget.buttonColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: const BorderSide(color: Colors.black, width: 0.25),
              ),
            ),
            child: Center(
              child: Text(
                _shiftEnabled ? tecla.toUpperCase() : tecla.toLowerCase(),
                style: TextStyle(fontSize: fontSize, color: widget.fontColor),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildButtonCustom(IconData icon) {
    final isBackspace = icon == Icons.backspace;
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = (constraints.maxHeight * 0.38).clamp(12.0, 40.0);
          return GestureDetector(
            onLongPressStart: isBackspace ? _startBackspaceTimer : null,
            onLongPressEnd: isBackspace ? _stopBackspaceTimer : null,
            child: ElevatedButton(
              onPressed: () {
                if (icon == Icons.backspace) {
                  if (widget.controller.text.isNotEmpty) {
                    final newText = widget.controller.text.substring(0, widget.controller.text.length - 1);
                    widget.controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                  }
                }
                if (icon == Icons.arrow_forward) {
                  widget.onSubmit?.call(widget.controller.text);
                }
                if (icon == Icons.arrow_upward) {
                  setState(() {
                    _shiftEnabled = !_shiftEnabled;
                  });
                }
                if (icon == Icons.space_bar) {
                  if (widget.controller.text.isNotEmpty) {
                    final newText = widget.controller.text + ' ';
                    widget.controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade400,
                backgroundColor: widget.buttonColor,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                  side: const BorderSide(color: Colors.black, width: 0.25),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: widget.iconColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildLanguageToggle() {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = (constraints.maxHeight * 0.38).clamp(12.0, 40.0);
          return ElevatedButton(
            onPressed: () {
              setState(() {
                _isArabic = !_isArabic;
              });
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade300,
              disabledBackgroundColor: Colors.grey.shade400,
              backgroundColor: widget.buttonColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: const BorderSide(color: Colors.black, width: 0.25),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.language,
                size: iconSize,
                color: widget.iconColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildBackSpaceCustom(IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final iconSize = (constraints.maxHeight * 0.38).clamp(12.0, 40.0);
          return ElevatedButton(
            onPressed: () {
              final newText = widget.controller.text + ' ';
              widget.controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.buttonColor,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: const BorderSide(color: Colors.black, width: 0.25),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: widget.iconColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Expanded(
      child: Row(children: children),
    );
  }

  List<Widget> _buildLatinLayout() {
    return [
      _buildRow([
        Flexible(child: buildButton('1')),
        Flexible(child: buildButton('2')),
        Flexible(child: buildButton('3')),
        Flexible(child: buildButton('4')),
        Flexible(child: buildButton('5')),
        Flexible(child: buildButton('6')),
        Flexible(child: buildButton('7')),
        Flexible(child: buildButton('8')),
        Flexible(child: buildButton('9')),
        Flexible(child: buildButton('0')),
      ]),
      _buildRow([
        Flexible(child: buildButton('a')),
        Flexible(child: buildButton('z')),
        Flexible(child: buildButton('e')),
        Flexible(child: buildButton('r')),
        Flexible(child: buildButton('t')),
        Flexible(child: buildButton('y')),
        Flexible(child: buildButton('u')),
        Flexible(child: buildButton('i')),
        Flexible(child: buildButton('o')),
        Flexible(child: buildButton('p')),
      ]),
      _buildRow([
        Flexible(child: buildButton('q')),
        Flexible(child: buildButton('s')),
        Flexible(child: buildButton('d')),
        Flexible(child: buildButton('f')),
        Flexible(child: buildButton('g')),
        Flexible(child: buildButton('h')),
        Flexible(child: buildButton('j')),
        Flexible(child: buildButton('k')),
        Flexible(child: buildButton('l')),
        Flexible(child: buildButton('m')),
      ]),
      _buildRow([
        Flexible(child: buildButtonCustom(Icons.arrow_upward)),
        Flexible(child: buildButton('w')),
        Flexible(child: buildButton('x')),
        Flexible(child: buildButton('c')),
        Flexible(child: buildButton('v')),
        Flexible(child: buildButton('b')),
        Flexible(child: buildButton('n')),
        Flexible(child: buildButton('@')),
        Flexible(child: buildButton('.')),
        Flexible(child: buildButtonCustom(Icons.backspace)),
      ]),
      _buildRow([
        Flexible(child: buildLanguageToggle()),
        Flexible(child: buildButton('#')),
        Flexible(child: buildButton('!')),
        Expanded(flex: 3, child: buildBackSpaceCustom(Icons.space_bar)),
        Flexible(child: buildButton('-')),
        Flexible(child: buildButton('_')),
        Expanded(flex: 2, child: buildButtonCustom(Icons.arrow_forward)),
      ]),
    ];
  }

  List<Widget> _buildArabicLayout() {
    return [
      _buildRow([
        Flexible(child: buildButton('1')),
        Flexible(child: buildButton('2')),
        Flexible(child: buildButton('3')),
        Flexible(child: buildButton('4')),
        Flexible(child: buildButton('5')),
        Flexible(child: buildButton('6')),
        Flexible(child: buildButton('7')),
        Flexible(child: buildButton('8')),
        Flexible(child: buildButton('9')),
        Flexible(child: buildButton('0')),
      ]),
      _buildRow([
        Flexible(child: buildButton('\u0636')),
        Flexible(child: buildButton('\u0635')),
        Flexible(child: buildButton('\u062B')),
        Flexible(child: buildButton('\u0642')),
        Flexible(child: buildButton('\u0641')),
        Flexible(child: buildButton('\u063A')),
        Flexible(child: buildButton('\u0639')),
        Flexible(child: buildButton('\u0647')),
        Flexible(child: buildButton('\u062E')),
        Flexible(child: buildButton('\u062D')),
        Flexible(child: buildButton('\u062C')),
      ]),
      _buildRow([
        Flexible(child: buildButton('\u0634')),
        Flexible(child: buildButton('\u0633')),
        Flexible(child: buildButton('\u064A')),
        Flexible(child: buildButton('\u0628')),
        Flexible(child: buildButton('\u0644')),
        Flexible(child: buildButton('\u0627')),
        Flexible(child: buildButton('\u062A')),
        Flexible(child: buildButton('\u0646')),
        Flexible(child: buildButton('\u0645')),
        Flexible(child: buildButton('\u0643')),
        Flexible(child: buildButton('\u0629')),
      ]),
      _buildRow([
        Flexible(child: buildButton('\u0637')),
        Flexible(child: buildButton('\u0638')),
        Flexible(child: buildButton('\u0630')),
        Flexible(child: buildButton('\u062F')),
        Flexible(child: buildButton('\u0631')),
        Flexible(child: buildButton('\u0648')),
        Flexible(child: buildButton('\u0632')),
        Flexible(child: buildButton('\u0621')),
        Flexible(child: buildButton('\u0649')),
        Flexible(child: buildButton('\u0624')),
        Flexible(child: buildButtonCustom(Icons.backspace)),
      ]),
      _buildRow([
        Flexible(child: buildLanguageToggle()),
        Flexible(child: buildButton('\u0622')),
        Flexible(child: buildButton('\u0625')),
        Expanded(flex: 3, child: buildBackSpaceCustom(Icons.space_bar)),
        Flexible(child: buildButton('\u0623')),
        Flexible(child: buildButton('\u0626')),
        Expanded(flex: 2, child: buildButtonCustom(Icons.arrow_forward)),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widget.keyboardType == KeyboardType.alphanumeric ? 0.85 : 0.45,
      child: AspectRatio(
        aspectRatio: widget.keyboardType == KeyboardType.alphanumeric ? 2.2 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            color: widget.backgroundColor,
          ),
          child: widget.keyboardType == KeyboardType.alphanumeric
              ? Column(
                  children: _isArabic ? _buildArabicLayout() : _buildLatinLayout(),
                )
              : Column(
                  children: [
                    _buildRow([
                      Flexible(child: buildButton('1')),
                      Flexible(child: buildButton('2')),
                      Flexible(child: buildButton('3')),
                      Flexible(child: buildButton('-')),
                    ]),
                    _buildRow([
                      Flexible(child: buildButton('4')),
                      Flexible(child: buildButton('5')),
                      Flexible(child: buildButton('6')),
                      Flexible(child: buildButtonCustom(Icons.space_bar)),
                    ]),
                    _buildRow([
                      Flexible(child: buildButton('7')),
                      Flexible(child: buildButton('8')),
                      Flexible(child: buildButton('9')),
                      Flexible(child: buildButtonCustom(Icons.backspace)),
                    ]),
                    _buildRow([
                      Flexible(child: buildButton('.')),
                      Flexible(child: buildButton('0')),
                      Flexible(child: buildButton(',')),
                      Flexible(child: buildButtonCustom(Icons.arrow_forward)),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}
