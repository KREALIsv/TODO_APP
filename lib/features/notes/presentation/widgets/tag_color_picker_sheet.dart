import 'package:flutter/material.dart';

import '../../../../global/themes/app_colors.dart';
import '../../../../global/widgets/app_alerts.dart';
import '../../domain/tag_colors.dart';

class TagColorPickerResult {
  const TagColorPickerResult({
    required this.title,
    required this.colorId,
    this.opacity = TagColors.defaultOpacity,
    this.deleted = false,
  });

  final String title;
  final String colorId;
  final double opacity;
  final bool deleted;
}

/// Panel embebible (misma ventana) o envuelto en bottom sheet standalone.
class TagColorPickerPanel extends StatefulWidget {
  const TagColorPickerPanel({
    super.key,
    this.initialTitle = '',
    this.initialColorId,
    this.initialOpacity = TagColors.defaultOpacity,
    this.allowDelete = false,
    this.showBackButton = false,
    this.sheetTitle = 'Crear etiqueta',
    this.confirmLabel = 'Crear',
    this.onBack,
    required this.onCompleted,
  });

  final String initialTitle;
  final String? initialColorId;
  final double initialOpacity;
  final bool allowDelete;
  final bool showBackButton;
  final String sheetTitle;
  final String confirmLabel;
  final VoidCallback? onBack;
  final ValueChanged<TagColorPickerResult> onCompleted;

  @override
  State<TagColorPickerPanel> createState() => _TagColorPickerPanelState();
}

class _TagColorPickerPanelState extends State<TagColorPickerPanel> {
  late final TextEditingController _titleController;
  late String _colorId;
  late double _opacity;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _colorId = TagColors.byId(widget.initialColorId ?? '')?.id ??
        TagColors.swatches.first.id;
    _opacity = TagColors.clampOpacity(widget.initialOpacity);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  TagSwatch get _swatch =>
      TagColors.byId(_colorId) ?? TagColors.swatches.first;

  TagColorPair get _pair => _swatch.pairWithOpacity(_opacity);

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    widget.onCompleted(
      TagColorPickerResult(
        title: title,
        colorId: _colorId,
        opacity: _opacity,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await AppAlerts.confirm(
      context,
      title: 'Eliminar etiqueta',
      message:
          'Se eliminará "${widget.initialTitle}" del catálogo y de las notas que la usen.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    widget.onCompleted(
      TagColorPickerResult(
        title: widget.initialTitle,
        colorId: _colorId,
        opacity: _opacity,
        deleted: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pair = _pair;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: Row(
            children: [
              if (widget.showBackButton)
                IconButton(
                  tooltip: 'Volver',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  widget.sheetTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pair.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _titleController.text.trim().isEmpty
                        ? 'Vista previa'
                        : _titleController.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      color: pair.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Título', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Nombre de la etiqueta',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Seleccionar un color', style: textTheme.labelLarge),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: TagColors.swatches.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final swatch = TagColors.swatches[index];
                    final selected = swatch.id == _colorId;
                    return Tooltip(
                      message: swatch.label,
                      child: InkWell(
                        onTap: () => setState(() => _colorId = swatch.id),
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: swatch.color,
                            borderRadius: BorderRadius.circular(6),
                            border: selected
                                ? Border.all(
                                    color: AppColors.black,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: TagColors.foregroundFor(swatch.color),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Opacidad', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                _OpacitySliderField(
                  value: _opacity,
                  color: _swatch.color,
                  onChanged: (value) {
                    setState(() => _opacity = value);
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: widget.allowDelete
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _titleController.text.trim().isEmpty
                            ? null
                            : _submit,
                        child: Text(widget.confirmLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        onPressed: _delete,
                        child: const Text('Eliminar'),
                      ),
                    ),
                  ],
                )
              : FilledButton(
                  onPressed:
                      _titleController.text.trim().isEmpty ? null : _submit,
                  child: Text(widget.confirmLabel),
                ),
        ),
      ],
    );
  }
}

/// Bottom sheet standalone (por si se usa fuera del flujo de etiquetas).
Future<TagColorPickerResult?> showTagColorPickerSheet(
  BuildContext context, {
  String initialTitle = '',
  String? initialColorId,
  double initialOpacity = TagColors.defaultOpacity,
  bool allowDelete = false,
  String sheetTitle = 'Crear etiqueta',
  String confirmLabel = 'Crear',
}) {
  return showModalBottomSheet<TagColorPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: TagColorPickerPanel(
            initialTitle: initialTitle,
            initialColorId: initialColorId,
            initialOpacity: initialOpacity,
            allowDelete: allowDelete,
            sheetTitle: sheetTitle,
            confirmLabel: confirmLabel,
            onCompleted: (result) => Navigator.of(context).pop(result),
          ),
        ),
      );
    },
  );
}

/// Barra de opacidad con la misma forma/borde que un TextField.
class _OpacitySliderField extends StatelessWidget {
  const _OpacitySliderField({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final percent = (value * 100).round();

    return InputDecorator(
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.25),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: value,
                min: TagColors.minOpacity,
                max: TagColors.maxOpacity,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.neutral80,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
