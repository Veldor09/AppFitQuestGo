import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Barra de paginacion tipica de tabla: selector de filas por pagina, rango
/// visible y flechas anterior / siguiente.
class PaginacionBar extends StatelessWidget {
  const PaginacionBar({
    super.key,
    required this.total,
    required this.pagina,
    required this.filasPorPagina,
    required this.opciones,
    required this.onFilasPorPagina,
    required this.onPagina,
  });

  final int total;
  final int pagina;
  final int filasPorPagina;
  final List<int> opciones;
  final ValueChanged<int> onFilasPorPagina;
  final ValueChanged<int> onPagina;

  int get _totalPaginas =>
      total == 0 ? 1 : ((total - 1) ~/ filasPorPagina) + 1;

  int get _desde => total == 0 ? 0 : pagina * filasPorPagina + 1;

  int get _hasta {
    final int fin = (pagina + 1) * filasPorPagina;
    return fin > total ? total : fin;
  }

  @override
  Widget build(BuildContext context) {
    final bool hayAnterior = pagina > 0;
    final bool haySiguiente = pagina < _totalPaginas - 1;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FqColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          const Text(
            'Filas por pagina',
            style: TextStyle(fontSize: 10, color: FqColors.muted),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: filasPorPagina,
              isDense: true,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FqColors.ink,
              ),
              items: opciones
                  .map(
                    (int n) => DropdownMenuItem<int>(
                      value: n,
                      child: Text('$n'),
                    ),
                  )
                  .toList(),
              onChanged: (int? v) {
                if (v != null) onFilasPorPagina(v);
              },
            ),
          ),
          const SizedBox(width: 22),
          Text(
            '$_desde–$_hasta de $total',
            style: const TextStyle(fontSize: 10, color: FqColors.muted),
          ),
          const SizedBox(width: 10),
          _Flecha(
            icon: Icons.chevron_left,
            onTap: hayAnterior ? () => onPagina(pagina - 1) : null,
          ),
          _Flecha(
            icon: Icons.chevron_right,
            onTap: haySiguiente ? () => onPagina(pagina + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _Flecha extends StatelessWidget {
  const _Flecha({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool activo = onTap != null;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: FqColors.ink,
      disabledColor: FqColors.stone,
      splashRadius: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      tooltip: activo
          ? (icon == Icons.chevron_left ? 'Anterior' : 'Siguiente')
          : null,
    );
  }
}
