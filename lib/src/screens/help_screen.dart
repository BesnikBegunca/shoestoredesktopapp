import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _selectedCategory = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ✅ Categories: përdor SVG path, jo IconData
  final List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'label': 'Të gjitha', 'svg': 'assets/icons/allc.svg'},
    {'id': 'shitja', 'label': 'Shitja', 'svg': 'assets/icons/soldtoday.svg'},
    {'id': 'stoku', 'label': 'Stoku', 'svg': 'assets/icons/inv.svg'},
    {'id': 'fitimet', 'label': 'Fitimet', 'svg': 'assets/icons/fitimi.svg'},
    {
      'id': 'shpenzimet',
      'label': 'Shpenzimet',
      'svg': 'assets/icons/expenses.svg',
    },
    {'id': 'licenca', 'label': 'Licenca', 'svg': 'assets/icons/key.svg'},
  ];

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'shitja',
      'question': 'Si të bëj një shitje?',
      'answer':
          'Për të bërë një shitje, shkoni në "Shitja Ditore", skanoni barcode-in e produktit ose kërkoni produktin manualisht. Shtoni sasitë dhe klikoni "Paguaj" për të përfunduar transaksionin.',
    },
    {
      'category': 'shitja',
      'question': 'Si të printoj faturën?',
      'answer':
          'Pas përfundimit të shitjes, klikoni butonin e printimit në ekranin e konfirmimit. Faturat printohen automatikisht në format 80mm për printerë POS.',
    },
    {
      'category': 'shitja',
      'question': 'Si të anuloj një shitje?',
      'answer':
          'Nëse shitja është bërë gabimisht, mund ta anuloni nga historiku i shitjeve. Kjo do të rikthejë stokun automatikisht.',
    },
    {
      'category': 'stoku',
      'question': 'Si të regjistoj produkte të reja?',
      'answer':
          'Shkoni në "Regjistrimi i Mallit", klikoni "Shto Produkt", plotësoni të dhënat (emri, çmimi, barcode, etj.) dhe ruani. Mund të shtoni edhe foto të produktit.',
    },
    {
      'category': 'stoku',
      'question': 'Si të menaxhoj stokun?',
      'answer':
          'Në seksionin "Stoku" mund të shihni të gjithë inventarin, të filtroni produktet sipas kategorive, dhe të shihni cilat produkte kanë stok të ulët.',
    },
    {
      'category': 'stoku',
      'question': 'Çfarë ndodh kur një produkt mbaron nga stoku?',
      'answer':
          'Sistemi ju paralajmëron automatikisht kur një produkt ka stok të ulët (< 5 copë). Produktet pa stok nuk mund të shiten derisa të rifreskoni inventarin.',
    },
    {
      'category': 'stoku',
      'question': 'Si të shtoj sasi të re në stok?',
      'answer':
          'Shkoni te produkti në "Regjistrimi i Mallit", klikoni Edit, dhe përditësoni sasinë e stokut. Sistemi do ta ruajë historikun e ndryshimeve.',
    },
    {
      'category': 'fitimet',
      'question': 'Si të shoh fitimet e ditës?',
      'answer':
          'Shkoni në "Fitimet", zgjidhni filtrin "Ditor" dhe do të shihni të gjitha shitjet, fitimin bruto, shpenzimet dhe fitimin neto për ditën e sotme.',
    },
    {
      'category': 'fitimet',
      'question': 'Si llogaritet fitimi?',
      'answer':
          'Fitimi bruto = Shitje Totale - Çmimi i Blerjes. Fitimi neto = Fitimi Bruto - Shpenzimet. Sistemi llogarit automatikisht bazuar në çmimet e blerjes dhe shitjes.',
    },
    {
      'category': 'fitimet',
      'question': 'Si të printoj raportin e fitimeve?',
      'answer':
          'Klikoni butonin e printimit në ekranin "Fitimet". Mund të zgjidhni periudhën (ditor, javor, mujor) para se të printoni raportin.',
    },
    {
      'category': 'shpenzimet',
      'question': 'Si të regjistoj shpenzime?',
      'answer':
          'Shkoni në "Shpenzimet", klikoni butonin "+", zgjidhni kategorinë (Rryma, Uji, Qiraja, etj.), vendosni shumën dhe shënimin, pastaj klikoni "Shto".',
    },
    {
      'category': 'shpenzimet',
      'question': 'Çfarë janë "Blerje Malli"?',
      'answer':
          '"Blerje Malli" janë investimet për blerjen e produkteve të reja për shitje. Këto regjistrohen automatikisht nga sistemi dhe ndikojnë në fitimin neto.',
    },
    {
      'category': 'shpenzimet',
      'question': 'Si të filtoj shpenzimet sipas kategorisë?',
      'answer':
          'Në ekranin "Shpenzimet", përdorni chips-at e kategorive për të filtruar. Mund të zgjidhni "Të gjitha" ose kategori specifike si Rryma, Uji, Qiraja, etj.',
    },
    {
      'category': 'licenca',
      'question': 'Si funksionon licenca?',
      'answer':
          'Aplikacioni kërkon një licencë aktive për të funksionuar. Licenca aktivizohet me një kod unik që merret nga administratori ose zhvilluesi.',
    },
    {
      'category': 'licenca',
      'question': 'Çfarë ndodh nëse licenca skadon?',
      'answer':
          'Nëse licenca skadon, aplikacioni do të kalojë në modalitet "readonly" ku mund të shikoni të dhënat por nuk mund të bëni shitje ose ndryshime.',
    },
    {
      'category': 'licenca',
      'question': 'Si të rinovojë licencën?',
      'answer':
          'Kontaktoni administratorin ose zhvilluesin për të marrë një kod rinovimi. Vendosni kodin në seksionin "Licenca" për të aktivizuar përsëri aplikacionin.',
    },
    {
      'category': 'shitja',
      'question': 'Si të përdor skanerin e barcode?',
      'answer':
          'Lidhni një skaner barcode USB me kompjuterin. Në ekranin "Shitja Ditore", fokusoni në fushën e kërkimit dhe skanoni produktin. Sistemi do ta gjejë dhe shtojë automatikisht.',
    },
    {
      'category': 'stoku',
      'question': 'Si të fshij një produkt?',
      'answer':
          'Shkoni te "Regjistrimi i Mallit", gjeni produktin, dhe klikoni ikonën e fshirjes në fund të rreshtit. Do të shfaqet një konfirmim para se të fshihet përfundimisht.',
    },
    {
      'category': 'fitimet',
      'question': 'A mund të shoh fitimet për një periudhë specifike?',
      'answer':
          'Po! Në ekranin "Fitimet" mund të zgjidhni ndërmjet tre periudhave: Ditor (sot), Javor (7 ditët e fundit), dhe Mujor (muaji aktual).',
    },
    {
      'category': 'shpenzimet',
      'question': 'Si të printoj raportin e shpenzimeve?',
      'answer':
          'Klikoni butonin e printimit në ekranin "Shpenzimet". Raporti do të përfshijë të gjitha shpenzimet për periudhën e zgjedhur, të grupuara sipas kategorive.',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFaqs {
    var filtered = _faqs.where((faq) {
      if (_selectedCategory != 'all' && faq['category'] != _selectedCategory) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final question = (faq['question'] as String).toLowerCase();
        final answer = (faq['answer'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return question.contains(query) || answer.contains(query);
      }

      return true;
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(color: AppTheme.bgPage),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // ✅ SVG header icon
                    const AppSvgIcon(
                      'assets/icons/info.svg',
                      size: 32,
                      color: AppTheme.text,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Help & FAQs',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gjej përgjigje për pyetjet më të shpeshta',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Kërko në FAQ...',
                      // ✅ SVG search icon
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppSvgIcon(
                          'assets/icons/search.svg',
                          size: 20,
                          color: AppTheme.muted,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              // ✅ SVG clear icon
                              icon: const AppSvgIcon(
                                'assets/icons/close.svg',
                                size: 18,
                                color: AppTheme.muted,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories
                  Row(
                    children: const [
                      AppSvgIcon(
                        'assets/icons/category.svg',
                        size: 20,
                        color: AppTheme.text,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Kategoritë:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _categories.map((cat) {
                      return _categoryChip(
                        cat['label'] as String,
                        cat['id'] as String,
                        cat['svg'] as String,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // FAQs Header
                  Row(
                    children: [
                      const AppSvgIcon(
                        'assets/icons/question.svg',
                        size: 20,
                        color: AppTheme.text,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_filteredFaqs.length} Pyetje & Përgjigje',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // FAQs List
                  if (_filteredFaqs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.stroke),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const AppSvgIcon(
                              'assets/icons/search_off.svg',
                              size: 64,
                              color: AppTheme.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'S\'u gjet asnjë rezultat',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredFaqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final faq = _filteredFaqs[i];
                        return _faqCard(faq);
                      },
                    ),

                  const SizedBox(height: 32),

                  // Contact Support Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: AppSvgIcon(
                              'assets/icons/support_agent.svg',
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nuk gjete përgjigjen?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Kontaktoni ekipin e mbështjes për ndihmë të mëtejshme',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email: support@example.com'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          icon: const AppSvgIcon(
                            'assets/icons/email.svg',
                            size: 18,
                            color: Colors.blue,
                          ),
                          label: const Text('Kontakto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ chip me SVG
  Widget _categoryChip(String label, String id, String svgAsset) {
    final isSelected = _selectedCategory == id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedCategory = id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : AppTheme.stroke,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(
                svgAsset,
                size: 18,
                color: isSelected ? Colors.white : AppTheme.text,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isSelected ? Colors.white : AppTheme.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqCard(Map<String, dynamic> faq) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(faq['category']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            // ✅ SVG icon për çdo FAQ (mundesh me e ndrru sipas kategorisë poshtë)
            child: Center(
              child: AppSvgIcon(
                'assets/icons/question.svg',
                size: 22,
                color: _getCategoryColor(faq['category']),
              ),
            ),
          ),
          title: Text(
            faq['question'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppTheme.text,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _getCategoryLabel(faq['category']),
              style: TextStyle(
                color: _getCategoryColor(faq['category']),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                faq['answer'] ?? '',
                style: TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SVG sipas kategorisë (përdor vetëm assets ekzistues)
  String _getCategorySvg(String category) {
    switch (category) {
      case 'shitja':
        return 'assets/icons/soldtoday.svg';
      case 'stoku':
        return 'assets/icons/inv.svg';
      case 'fitimet':
        return 'assets/icons/fitimi.svg';
      case 'shpenzimet':
        return 'assets/icons/expenses.svg';
      case 'licenca':
        return 'assets/icons/key.svg';
      default:
        return 'assets/icons/question.svg';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'shitja':
        return Colors.blue;
      case 'stoku':
        return Colors.purple;
      case 'fitimet':
        return Colors.green;
      case 'shpenzimet':
        return Colors.red;
      case 'licenca':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'shitja':
        return 'SHITJA';
      case 'stoku':
        return 'STOKU';
      case 'fitimet':
        return 'FITIMET';
      case 'shpenzimet':
        return 'SHPENZIMET';
      case 'licenca':
        return 'LICENCA';
      default:
        return category.toUpperCase();
    }
  }
}

class AppSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const AppSvgIcon(this.asset, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(Icons.image, size: size, color: color),
      excludeFromSemantics: true,
    );
  }
}
