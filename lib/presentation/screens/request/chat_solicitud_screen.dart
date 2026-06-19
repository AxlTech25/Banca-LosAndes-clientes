import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/fase4_models.dart';
import '../../viewmodels/chat_solicitud_view_model.dart';

class ChatSolicitudScreen extends StatefulWidget {
  const ChatSolicitudScreen({
    super.key,
    required this.solicitudId,
    this.numeroExpediente,
  });

  final String solicitudId;
  final String? numeroExpediente;

  @override
  State<ChatSolicitudScreen> createState() => _ChatSolicitudScreenState();
}

class _ChatSolicitudScreenState extends State<ChatSolicitudScreen> {
  late final ChatSolicitudViewModel _viewModel;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = ChatSolicitudViewModel(solicitudId: widget.solicitudId);
    _viewModel.startListening();
    _viewModel.load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final ok = await _viewModel.enviar(text);
    if (!mounted) return;
    if (ok) {
      _messageController.clear();
      _scrollToBottom();
    } else if (_viewModel.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.numeroExpediente ?? 'Chat';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: _buildMessageList(),
              ),
              if (!_viewModel.chatNoDisponible)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                hintText: 'Escribe un mensaje...',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _viewModel.isSending ? null : _send,
                            icon: _viewModel.isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.chatNoDisponible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Chat no configurado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Falta crear la tabla en Supabase. Ejecuta la migracion '
                '008_fase4_pagos_firma_chat_buro.sql en el SQL Editor.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.mensajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Escribe un mensaje a tu asesor sobre esta solicitud.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.mensajes.length,
      itemBuilder: (context, index) {
        final msg = _viewModel.mensajes[index];
        return _Bubble(mensaje: msg);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.mensaje});

  final MensajeSolicitudModel mensaje;

  @override
  Widget build(BuildContext context) {
    final esPropio = mensaje.esPropio;
    final contenido = mensaje.contenido;
    final createdAt = mensaje.createdAt;

    return Align(
      alignment: esPropio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: esPropio
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!esPropio)
              Text(
                'Asesor',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(contenido),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                createdAt.length >= 16
                    ? createdAt.substring(0, 16).replaceFirst('T', ' ')
                    : createdAt,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
