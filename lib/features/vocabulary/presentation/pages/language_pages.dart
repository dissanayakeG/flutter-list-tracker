import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:list_tracker/data/local/app_database.dart';
import 'package:list_tracker/data/repository/repository_validation.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_batch_parser.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_providers.dart';
import 'package:list_tracker/features/vocabulary/data/vocabulary_repository.dart';
import 'package:list_tracker/ui/common/widgets/anchored_select_field.dart';

enum _TaxonomyMode { existing, newItem }

enum _SubcategoryMode { general, existing, newItem }

class LanguagesPage extends ConsumerWidget {
  const LanguagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languages = ref.watch(languagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Languages')),
      body: languages.when(
        data: (items) => items.isEmpty
            ? const _VocabularyEmptyState(
                icon: Icons.translate_outlined,
                title: 'No languages yet.',
                message: 'Add a language to start building your dictionary.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final language = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.language_outlined),
                      title: Text(language.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () =>
                                context.push('/languages/${language.id}/edit'),
                            tooltip: 'Edit ${language.name}',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push('/languages/${language.id}'),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _VocabularyErrorState(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-language-fab',
        onPressed: () => context.push('/languages/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add language'),
      ),
    );
  }
}

class AddLanguagePage extends ConsumerStatefulWidget {
  const AddLanguagePage({super.key});

  @override
  ConsumerState<AddLanguagePage> createState() => _AddLanguagePageState();
}

class _AddLanguagePageState extends ConsumerState<AddLanguagePage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .createLanguage(_controller.text);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) _showMessage(context, 'Unable to save language.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LanguageNameForm(
      title: 'Add language',
      controller: _controller,
      isSaving: _isSaving,
      onSave: _save,
      formKey: _formKey,
    );
  }
}

class EditLanguagePage extends ConsumerStatefulWidget {
  const EditLanguagePage({super.key, required this.languageId});

  final int languageId;

  @override
  ConsumerState<EditLanguagePage> createState() => _EditLanguagePageState();
}

class _EditLanguagePageState extends ConsumerState<EditLanguagePage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  var _isSaving = false;
  var _didInitialise = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .updateLanguage(id: widget.languageId, name: _controller.text);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) _showMessage(context, 'Unable to update language.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref
        .watch(languagesProvider)
        .whenData(
          (items) =>
              items.where((item) => item.id == widget.languageId).firstOrNull,
        );
    return language.when(
      data: (item) {
        if (item == null) {
          return const Scaffold(
            body: _VocabularyErrorState(message: 'Language not found.'),
          );
        }
        if (!_didInitialise) {
          _controller.text = item.name;
          _didInitialise = true;
        }
        return _LanguageNameForm(
          title: 'Edit language',
          controller: _controller,
          isSaving: _isSaving,
          onSave: _save,
          formKey: _formKey,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: _VocabularyErrorState()),
    );
  }
}

class _LanguageNameForm extends StatelessWidget {
  const _LanguageNameForm({
    required this.title,
    required this.controller,
    required this.isSaving,
    required this.onSave,
    required this.formKey,
  });

  final String title;
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('language-name-field'),
                      controller: controller,
                      autofocus: true,
                      maxLength: languageNameMaxLength,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        hintText: 'For example, Spanish',
                      ),
                      validator: (value) => validateName(
                        value: value,
                        label: 'language',
                        fieldName: 'language',
                        maxLength: languageNameMaxLength,
                      ),
                      onFieldSubmitted: (_) => isSaving ? null : onSave(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: isSaving ? null : onSave,
                      child: Text(isSaving ? 'Saving…' : 'Save language'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LanguageDictionaryPage extends ConsumerWidget {
  const LanguageDictionaryPage({super.key, required this.languageId});

  final int languageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languages = ref.watch(languagesProvider);
    final words = ref.watch(vocabularyWordsProvider(languageId));
    final languageName = languages.asData?.value
        .where((item) => item.id == languageId)
        .firstOrNull
        ?.name;
    return Scaffold(
      appBar: AppBar(title: Text(languageName ?? 'Dictionary')),
      body: words.when(
        data: (items) => items.isEmpty
            ? const _VocabularyEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No words yet.',
                message: 'Add words to start your dictionary.',
              )
            : _DictionaryView(languageId: languageId, words: items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _VocabularyErrorState(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/languages/$languageId/add-words'),
        icon: const Icon(Icons.playlist_add),
        label: const Text('Add words'),
      ),
    );
  }
}

class _DictionaryView extends ConsumerWidget {
  const _DictionaryView({required this.languageId, required this.words});

  final int languageId;
  final List<VocabularyWordWithContext> words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byCategory = <int, List<VocabularyWordWithContext>>{};
    for (final item in words) {
      byCategory.putIfAbsent(item.category.id, () => []).add(item);
    }
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: constraints.maxWidth > 760 ? 720 : constraints.maxWidth,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: byCategory.values
                .expand((categoryWords) {
                  final category = categoryWords.first.category;
                  final bySubcategory =
                      <int?, List<VocabularyWordWithContext>>{};
                  for (final item in categoryWords) {
                    bySubcategory
                        .putIfAbsent(item.subcategory?.id, () => [])
                        .add(item);
                  }
                  final general = bySubcategory.remove(null);
                  final subgroups = bySubcategory.values.toList()
                    ..sort(
                      (left, right) => left.first.subcategory!.name.compareTo(
                        right.first.subcategory!.name,
                      ),
                    );
                  return <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 5),
                      child: Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (general != null) ...[
                      _GroupHeading(title: 'General'),
                      _WordGroupCard(languageId: languageId, items: general),
                    ],
                    ...subgroups.expand(
                      (group) => [
                        _GroupHeading(title: group.first.subcategory!.name),
                        _WordGroupCard(languageId: languageId, items: group),
                      ],
                    ),
                  ];
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _WordGroupCard extends StatelessWidget {
  const _WordGroupCard({required this.languageId, required this.items});

  final int languageId;
  final List<VocabularyWordWithContext> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CompactWordRow(languageId: languageId, item: items[index]),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CompactWordRow extends ConsumerWidget {
  const _CompactWordRow({required this.languageId, required this.item});

  final int languageId;
  final VocabularyWordWithContext item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final word = item.word;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      decoration: word.isCompleted ? TextDecoration.lineThrough : null,
    );
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${word.word} — ${word.meaning}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Checkbox(
            value: word.isCompleted,
            visualDensity: VisualDensity.compact,
            semanticLabel: 'Mark ${word.word} completed',
            onChanged: (value) async {
              if (value == null) return;
              try {
                await ref
                    .read(vocabularyRepositoryProvider)
                    .setWordCompleted(id: word.id, isCompleted: value);
              } catch (_) {
                if (context.mounted) {
                  _showMessage(context, 'Unable to update word.');
                }
              }
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => context.push(
              '/languages/$languageId/words/${word.id}/edit',
              extra: item,
            ),
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit ${word.word}',
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class AddWordsPage extends ConsumerStatefulWidget {
  const AddWordsPage({super.key, this.initialLanguageId});

  final int? initialLanguageId;

  @override
  ConsumerState<AddWordsPage> createState() => _AddWordsPageState();
}

class _AddWordsPageState extends ConsumerState<AddWordsPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _newSubcategoryController = TextEditingController();
  int? _languageId;
  int? _categoryId;
  int? _subcategoryId;
  var _categoryMode = _TaxonomyMode.existing;
  var _subcategoryMode = _SubcategoryMode.general;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _languageId = widget.initialLanguageId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _newCategoryController.dispose();
    _newSubcategoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _languageId == null) return;
    late List<VocabularyWordDraft> drafts;
    try {
      drafts = const VocabularyBatchParser().parse(_controller.text);
    } on VocabularyBatchFormatException catch (error) {
      if (mounted) _showMessage(context, error.message);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(vocabularyRepositoryProvider);
      final categoryId = _categoryMode == _TaxonomyMode.newItem
          ? (await repository.createCategory(name: _newCategoryController.text))
                .id
          : _categoryId!;
      final subcategoryId = switch (_subcategoryMode) {
        _SubcategoryMode.general => null,
        _SubcategoryMode.existing => _subcategoryId,
        _SubcategoryMode.newItem => (await repository.createSubcategory(
          categoryId: categoryId,
          name: _newSubcategoryController.text,
        )).id,
      };
      final count = await ref
          .read(vocabularyRepositoryProvider)
          .createWords(
            languageId: _languageId!,
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            drafts: drafts,
          );
      if (!mounted) return;
      _showMessage(context, '$count ${count == 1 ? 'word' : 'words'} added.');
      context.pop();
    } catch (error) {
      if (mounted) _showMessage(context, 'Unable to add words: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = ref.watch(languagesProvider);
    final categories = ref.watch(vocabularyCategoriesProvider);
    final subcategories = _categoryId == null
        ? null
        : ref.watch(vocabularySubcategoriesProvider(_categoryId!));
    return Scaffold(
      appBar: AppBar(title: const Text('Add words')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  languages.when(
                    data: (items) => AnchoredSelectField<int>(
                      key: const ValueKey('word-language-field'),
                      value: _languageId,
                      labelText: 'Language',
                      hintText: 'Select a language',
                      items: items
                          .map(
                            (item) => AnchoredSelectItem(
                              value: item.id,
                              label: item.name,
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() {
                              _languageId = value;
                              _categoryId = null;
                              _subcategoryId = null;
                            }),
                      validator: (value) =>
                          value == null ? 'Select a language.' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Unable to load languages.'),
                  ),
                  const SizedBox(height: 16),
                  if (_languageId != null)
                    Column(
                      children: [
                        SegmentedButton<_TaxonomyMode>(
                          segments: const [
                            ButtonSegment(
                              value: _TaxonomyMode.existing,
                              label: Text('Existing category'),
                            ),
                            ButtonSegment(
                              value: _TaxonomyMode.newItem,
                              label: Text('New category'),
                            ),
                          ],
                          selected: {_categoryMode},
                          onSelectionChanged: _isSaving
                              ? null
                              : (value) => setState(() {
                                  _categoryMode = value.first;
                                  _categoryId = null;
                                  _subcategoryId = null;
                                  _subcategoryMode = _SubcategoryMode.general;
                                }),
                        ),
                        const SizedBox(height: 12),
                        if (_categoryMode == _TaxonomyMode.newItem)
                          TextFormField(
                            controller: _newCategoryController,
                            decoration: const InputDecoration(
                              labelText: 'New category',
                            ),
                            validator: (value) => validateName(
                              value: value,
                              label: 'category',
                              fieldName: 'category',
                              maxLength: vocabularyCategoryNameMaxLength,
                            ),
                          )
                        else
                          categories.when(
                            data: (items) => AnchoredSelectField<int>(
                              key: ValueKey('word-category-field-$_languageId'),
                              value: _categoryId,
                              labelText: 'Category',
                              hintText: 'Select a category',
                              items: items
                                  .map(
                                    (item) => AnchoredSelectItem(
                                      value: item.id,
                                      label: item.name,
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isSaving
                                  ? null
                                  : (value) => setState(() {
                                      _categoryId = value;
                                      _subcategoryId = null;
                                    }),
                              validator: (value) =>
                                  value == null ? 'Select a category.' : null,
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) =>
                                const Text('Unable to load categories.'),
                          ),
                      ],
                    )
                  else
                    const Text('Select a language to choose a category.'),
                  const SizedBox(height: 16),
                  if (_categoryMode == _TaxonomyMode.newItem)
                    Column(
                      children: [
                        SegmentedButton<_SubcategoryMode>(
                          segments: const [
                            ButtonSegment(
                              value: _SubcategoryMode.general,
                              label: Text('General'),
                            ),
                            ButtonSegment(
                              value: _SubcategoryMode.newItem,
                              label: Text('New subcategory'),
                            ),
                          ],
                          selected: {_subcategoryMode},
                          onSelectionChanged: _isSaving
                              ? null
                              : (value) => setState(
                                  () => _subcategoryMode = value.first,
                                ),
                        ),
                        if (_subcategoryMode == _SubcategoryMode.newItem) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newSubcategoryController,
                            decoration: const InputDecoration(
                              labelText: 'New subcategory',
                            ),
                            validator: (value) => validateName(
                              value: value,
                              label: 'subcategory',
                              fieldName: 'subcategory',
                              maxLength: vocabularySubcategoryNameMaxLength,
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (subcategories != null)
                    Column(
                      children: [
                        SegmentedButton<_SubcategoryMode>(
                          segments: const [
                            ButtonSegment(
                              value: _SubcategoryMode.general,
                              label: Text('General'),
                            ),
                            ButtonSegment(
                              value: _SubcategoryMode.existing,
                              label: Text('Existing'),
                            ),
                            ButtonSegment(
                              value: _SubcategoryMode.newItem,
                              label: Text('New'),
                            ),
                          ],
                          selected: {_subcategoryMode},
                          onSelectionChanged: _isSaving
                              ? null
                              : (value) => setState(
                                  () => _subcategoryMode = value.first,
                                ),
                        ),
                        const SizedBox(height: 12),
                        if (_subcategoryMode == _SubcategoryMode.newItem)
                          TextFormField(
                            controller: _newSubcategoryController,
                            decoration: const InputDecoration(
                              labelText: 'New subcategory',
                            ),
                            validator: (value) => validateName(
                              value: value,
                              label: 'subcategory',
                              fieldName: 'subcategory',
                              maxLength: vocabularySubcategoryNameMaxLength,
                            ),
                          )
                        else if (_subcategoryMode == _SubcategoryMode.existing)
                          subcategories.when(
                            data: (items) => AnchoredSelectField<int>(
                              key: ValueKey(
                                'word-subcategory-field-$_categoryId',
                              ),
                              value: _subcategoryId,
                              labelText: 'Subcategory',
                              hintText: 'Select a subcategory',
                              items: items
                                  .map(
                                    (item) => AnchoredSelectItem(
                                      value: item.id,
                                      label: item.name,
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isSaving
                                  ? null
                                  : (value) =>
                                        setState(() => _subcategoryId = value),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) =>
                                const Text('Unable to load subcategories.'),
                          ),
                      ],
                    )
                  else
                    const Text('Select a category to choose a subcategory.'),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('word-batch-field'),
                    controller: _controller,
                    minLines: 7,
                    maxLines: 12,
                    maxLength: 10000,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Words and meanings',
                      hintText: 'hola,hello\nnoche,"night, evening"',
                      helperText: 'One word and meaning pair per line.',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter at least one word.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Adding…' : 'Add words'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditVocabularyWordPage extends ConsumerStatefulWidget {
  const EditVocabularyWordPage({super.key, required this.item});

  final VocabularyWordWithContext item;

  @override
  ConsumerState<EditVocabularyWordPage> createState() =>
      _EditVocabularyWordPageState();
}

class _EditVocabularyWordPageState
    extends ConsumerState<EditVocabularyWordPage> {
  late final TextEditingController _wordController;
  late final TextEditingController _meaningController;
  late int _categoryId;
  int? _subcategoryId;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.item.word.word);
    _meaningController = TextEditingController(text: widget.item.word.meaning);
    _categoryId = widget.item.category.id;
    _subcategoryId = widget.item.subcategory?.id;
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(vocabularyRepositoryProvider)
          .updateWord(
            id: widget.item.word.id,
            languageId: widget.item.word.languageId,
            categoryId: _categoryId,
            subcategoryId: _subcategoryId,
            word: _wordController.text,
            meaning: _meaningController.text,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) _showMessage(context, 'Unable to update word: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(vocabularyCategoriesProvider);
    final subcategories = ref.watch(
      vocabularySubcategoriesProvider(_categoryId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Edit word')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextField(
                  controller: _wordController,
                  maxLength: vocabularyWordMaxLength,
                  decoration: const InputDecoration(labelText: 'Word'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _meaningController,
                  maxLength: vocabularyMeaningMaxLength,
                  decoration: const InputDecoration(labelText: 'Meaning'),
                ),
                const SizedBox(height: 12),
                categories.when(
                  data: (items) => AnchoredSelectField<int>(
                    value: _categoryId,
                    labelText: 'Category',
                    items: items
                        .map(
                          (item) => AnchoredSelectItem(
                            value: item.id,
                            label: item.name,
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() {
                            _categoryId = value;
                            _subcategoryId = null;
                          }),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Unable to load categories.'),
                ),
                const SizedBox(height: 12),
                subcategories.when(
                  data: (items) => AnchoredSelectField<int?>(
                    key: ValueKey('edit-word-subcategory-$_categoryId'),
                    value: _subcategoryId,
                    hasValue: true,
                    labelText: 'Subcategory',
                    items: [
                      const AnchoredSelectItem<int?>(
                        value: null,
                        label: 'General (no subcategory)',
                      ),
                      ...items.map(
                        (item) => AnchoredSelectItem<int?>(
                          value: item.id,
                          label: item.name,
                        ),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _subcategoryId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text('Unable to load subcategories.'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VocabularyCategoryManagementPage extends ConsumerWidget {
  const VocabularyCategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(vocabularyCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary categories')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: categories.when(
            data: (items) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _editNameDialog(
                          context: context,
                          title: 'Add category',
                          onSave: (name) => ref
                              .read(vocabularyRepositoryProvider)
                              .createCategory(name: name),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add category'),
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const Text('No vocabulary categories yet.'),
                      ...items.map(
                        (item) => Card(
                          child: ListTile(
                            title: Text(item.name),
                            subtitle: const Text('Manage subcategories'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit ${item.name}',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editNameDialog(
                                    context: context,
                                    title: 'Edit category',
                                    initialValue: item.name,
                                    onSave: (name) => ref
                                        .read(vocabularyRepositoryProvider)
                                        .updateCategory(
                                          id: item.id,
                                          name: name,
                                        ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => context.push(
                              '/language-categories/${item.id}',
                              extra: item,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _VocabularyErrorState(),
          ),
        ),
      ),
    );
  }
}

class VocabularySubcategoryManagementPage extends ConsumerWidget {
  const VocabularySubcategoryManagementPage({
    super.key,
    required this.category,
  });

  final VocabularyCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategories = ref.watch(
      vocabularySubcategoriesProvider(category.id),
    );
    return Scaffold(
      appBar: AppBar(title: Text('${category.name} subcategories')),
      body: subcategories.when(
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              onPressed: () => _editNameDialog(
                context: context,
                title: 'Add subcategory',
                onSave: (name) => ref
                    .read(vocabularyRepositoryProvider)
                    .createSubcategory(categoryId: category.id, name: name),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add subcategory'),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Words can still be added under General.'),
            ...items.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.name),
                  trailing: IconButton(
                    tooltip: 'Edit ${item.name}',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editNameDialog(
                      context: context,
                      title: 'Edit subcategory',
                      initialValue: item.name,
                      onSave: (name) => ref
                          .read(vocabularyRepositoryProvider)
                          .updateSubcategory(id: item.id, name: name),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _VocabularyErrorState(),
      ),
    );
  }
}

Future<void> _editNameDialog({
  required BuildContext context,
  required String title,
  required Future<Object?> Function(String name) onSave,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await onSave(controller.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  _showMessage(
                    dialogContext,
                    'Unable to save. Check for a duplicate name.',
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _VocabularyEmptyState extends StatelessWidget {
  const _VocabularyEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _VocabularyErrorState extends StatelessWidget {
  const _VocabularyErrorState({this.message = 'Unable to load vocabulary.'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
