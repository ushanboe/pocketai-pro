import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:pocketai/core/models/model_info.dart';
import 'package:pocketai/core/providers/model_provider.dart';
import 'package:pocketai/core/providers/settings_provider.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  String _selectedFilter = 'All';
  List<ModelInfo> _filteredModels = [];
  String? _expandedModelId;
  final double _deviceRamGB = 4.0;
  final double _totalStorageGB = 64.0;
  int _usedStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilter(context.read<ModelProvider>().models);
    });
  }

  void _applyFilter(List<ModelInfo> models) {
    List<ModelInfo> filtered;
    switch (_selectedFilter) {
      case 'Downloaded':
        filtered = models.where((m) => m.isDownloaded).toList();
        break;
      case 'Available':
        filtered = models.where((m) => !m.isDownloaded).toList();
        break;
      default:
        filtered = List.from(models);
    }
    filtered.sort((a, b) => a.name.compareTo(b.name));
    _filteredModels = filtered;
    _usedStorageBytes = models
        .where((m) => m.isDownloaded)
        .fold(0, (sum, m) => sum + m.sizeBytes);
  }

  Future<void> _refreshModels() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final models = context.read<ModelProvider>().models;
    setState(() {
      _applyFilter(models);
    });
  }

  void _showDeleteDialog(BuildContext context, ModelInfo model) {
    final sizeStr = model.sizeString;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete model?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will free $sizeStr of storage. You can re-download it later.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final settingsProvider = context.read<SettingsProvider>();
              final modelProvider = context.read<ModelProvider>();
              if (settingsProvider.settings.selectedModelId == model.id) {
                settingsProvider.setActiveModel('', '');
              }
              modelProvider.deleteModel(model.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBar() {
    final usedGB = _usedStorageBytes / 1000000000.0;
    final fraction = (_usedStorageBytes / (_totalStorageGB * 1000000000.0))
        .clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storage_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              const Text(
                'Storage',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const Spacer(),
              Text(
                '${usedGB.toStringAsFixed(1)} GB used of ${_totalStorageGB.toStringAsFixed(0)} GB',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: const Color(0xFF334155),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Downloaded', 'Available'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                    _applyFilter(context.read<ModelProvider>().models);
                  });
                }
              },
              selectedColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFF1E293B),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF334155),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompatBadge(ModelInfo model) {
    final compat = model.compatibilityForRam(_deviceRamGB);
    Color bgColor;
    Color textColor;
    switch (compat) {
      case 'Compatible':
        bgColor = const Color(0xFF064E3B);
        textColor = const Color(0xFF34D399);
        break;
      case 'May be slow':
        bgColor = const Color(0xFF451A03);
        textColor = const Color(0xFFFBBF24);
        break;
      default:
        bgColor = const Color(0xFF450A0A);
        textColor = const Color(0xFFF87171);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        compat,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuantBadge(ModelInfo model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        model.quantization,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF60A5FA),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCapabilityBadge(ModelInfo model) {
    Color bgColor;
    Color textColor;
    switch (model.capabilityTag) {
      case 'Chat':
        bgColor = const Color(0xFF1E1B4B);
        textColor = const Color(0xFFA5B4FC);
        break;
      case 'Reasoning':
        bgColor = const Color(0xFF1A1A2E);
        textColor = const Color(0xFFC084FC);
        break;
      case 'Instruct':
        bgColor = const Color(0xFF0C1A2E);
        textColor = const Color(0xFF38BDF8);
        break;
      case 'Vision':
        bgColor = const Color(0xFF1A2E1A);
        textColor = const Color(0xFF4ADE80);
        break;
      default:
        bgColor = const Color(0xFF1E293B);
        textColor = const Color(0xFF94A3B8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        model.capabilityTag == 'Vision' ? 'Vision Beta' : model.capabilityTag,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActiveLoadedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, size: 12, color: Color(0xFF34D399)),
          SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF34D399),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(ModelInfo model) {
    final percent = (model.downloadProgress * 100).toInt();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: model.downloadProgress,
            strokeWidth: 2,
            backgroundColor: const Color(0xFF334155),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            context.read<ModelProvider>().cancelDownload(model.id);
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Cancel', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildModelCard(ModelInfo model, BuildContext context) {
    final isExpanded = _expandedModelId == model.id;
    final isDownloading = model.downloadProgress > 0.0 && !model.isDownloaded;
    final settingsProvider = context.watch<SettingsProvider>();
    final isActiveInSettings =
        settingsProvider.settings.selectedModelId == model.id;

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: model.isActive || isActiveInSettings
                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                : const Color(0xFF334155),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — tap to expand/collapse
            GestureDetector(
              onTap: () {
                setState(() {
                  _expandedModelId = isExpanded ? null : model.id;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                model.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildCompatBadge(model),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildQuantBadge(model),
                            const SizedBox(width: 6),
                            _buildCapabilityBadge(model),
                            const SizedBox(width: 6),
                            Text(
                              model.parameterCount,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              model.sizeString,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (model.isActive || isActiveInSettings)
                    _buildActiveLoadedBadge(),
                ],
              ),
            ),
            ),

            // Animated description
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  model.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (model.isDownloaded)
                    OutlinedButton(
                      onPressed: () => _showDeleteDialog(context, model),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontSize: 13)),
                    ),
                  const Spacer(),
                  if (!model.isDownloaded && !isDownloading)
                    ElevatedButton(
                      onPressed: () async {
                        final provider = context.read<ModelProvider>();
                        provider.clearError();
                        await provider.startDownload(model.id);
                        if (provider.lastError != null && mounted) {
                          final errMsg = provider.lastError!.length > 80
                              ? '${provider.lastError!.substring(0, 80)}...'
                              : provider.lastError!;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errMsg, maxLines: 2, overflow: TextOverflow.ellipsis),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          provider.clearError();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Download',
                          style: TextStyle(fontSize: 13)),
                    ),
                  if (isDownloading) _buildDownloadProgress(model),
                  if (model.isDownloaded && !isActiveInSettings) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<SettingsProvider>()
                            .setActiveModel(model.id, model.name);
                        context
                            .read<ModelProvider>()
                            .setActiveModel(model.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${model.name} is now active'),
                            backgroundColor: const Color(0xFF064E3B),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Set Active',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildEmptyDownloadedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.download_outlined,
            size: 48,
            color: Color(0xFF334155),
          ),
          const SizedBox(height: 16),
          const Text(
            'No models downloaded',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilter = 'All';
                _applyFilter(context.read<ModelProvider>().models);
              });
            },
            child: const Text(
              'Browse all models',
              style: TextStyle(color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final models = context.watch<ModelProvider>().models;

    // Update filter whenever models change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _applyFilter(models);
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Models',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF94A3B8)),
            onPressed: _refreshModels,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStorageBar(),
          _buildFilterChips(),
          Expanded(
            child: _filteredModels.isEmpty && _selectedFilter == 'Downloaded'
                ? _buildEmptyDownloadedState()
                : RefreshIndicator(
                    color: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: _refreshModels,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredModels.length,
                      itemBuilder: (ctx, i) => _buildModelCard(
                        _filteredModels[i],
                        ctx,
                      )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: i * 80))
                          .slideY(begin: 0.2, end: 0),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
