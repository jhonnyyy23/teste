#!/usr/bin/env python3
"""
Baixa os enigmas diários do puzzleship.com (os 6 níveis) e salva em dados/AAAA-MM-DD.js,
que o index.html carrega. Versão para Linux do atualizar.ps1.

Uso:
  python3 debian/atualizar.py                  # enigma de hoje (e de ontem, se ainda faltar)
  python3 debian/atualizar.py --data 2026-10-05

Só o enigma do dia vem completo: dias anteriores ficam bloqueados para
assinantes no site original (pistas cortadas) e são recusados.
"""
import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys
import urllib.request

RAIZ = pathlib.Path(__file__).resolve().parent.parent
URL = 'https://www.puzzleship.com/logic/einstein-riddles/p/{}'
UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'


def baixar(url):
    if shutil.which('curl'):
        r = subprocess.run(['curl', '-sS', '-f', '--max-time', '60', url], capture_output=True)
        if r.returncode != 0:
            raise RuntimeError(r.stderr.decode(errors='replace').strip() or f'curl saiu com {r.returncode}')
        return r.stdout.decode('utf-8')
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode('utf-8')


def get_pack(dia):
    html = baixar(URL.format(dia))
    # junta os pedaços do payload do Next.js embutidos na página
    partes = re.findall(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)', html)
    t = ''.join(json.loads(p) for p in partes)
    i = t.find('"pack":{')
    if i < 0:
        raise RuntimeError('pacote não encontrado na página')
    obj, fim = json.JSONDecoder().raw_decode(t, i + 7)
    if obj.get('dateSlug') != dia:
        raise RuntimeError(f"a página devolveu o dia {obj.get('dateSlug')}")
    # dias antigos vêm "bloqueados" (só para assinantes), com parte das pistas cortada
    m = re.search(r'"isLocked":(true|false)', t[fim:fim + 400])
    if not m or m.group(1) != 'false':
        raise RuntimeError('dia bloqueado no site original (pistas incompletas)')
    # guarda só o necessário para o jogo
    return {
        'num': obj['num'],
        'data': obj['dateSlug'],
        'niveis': [{
            'nivel': it['level'],
            'categorias': [{'nome': a['name'], 'itens': a['items']} for a in it['house']['attributes']],
            'solucao': it['solution'],
            'pistas': [{'regra': [c['rule'][0], c['rule'][1]], 'texto': c['text']} for c in it['clues']],
        } for it in obj['items']],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data')
    ap.add_argument('--dias', type=int, default=1)
    ap.add_argument('--saida', default=str(RAIZ / 'dados'))
    a = ap.parse_args()
    saida = pathlib.Path(a.saida)
    saida.mkdir(parents=True, exist_ok=True)

    if a.data:
        lista = [a.data]
    else:
        hoje = dt.datetime.now(dt.timezone.utc).date()
        lista = [(hoje - dt.timedelta(days=n)).isoformat() for n in range(a.dias + 1)]

    tentativas = sucessos = 0
    for dia in lista:
        arq = saida / f'{dia}.js'
        if arq.exists() and not a.data:
            continue
        tentativas += 1
        try:
            pack = get_pack(dia)
            js = f"(window.PACKS = window.PACKS || {{}})['{dia}'] = " + json.dumps(pack, ensure_ascii=False, separators=(',', ':')) + ';\n'
            arq.write_text(js, encoding='utf-8')
            print(f"OK  {dia}  (#{pack['num']})")
            sucessos += 1
        except Exception as e:  # noqa: BLE001
            print(f'--  {dia}  não disponível: {e}')

    # índice com as datas disponíveis (o navegador não consegue listar a pasta sozinho)
    datas = sorted(p.stem for p in saida.glob('????-??-??.js'))
    (saida / 'indice.js').write_text('window.DATAS = ' + json.dumps(datas, separators=(',', ':')) + ';\n', encoding='utf-8')
    print(f'{len(datas)} dia(s) disponíveis em {saida}')

    if tentativas > 1 and sucessos == 0:
        print('ERRO: nenhum enigma pôde ser baixado.')
        sys.exit(1)


if __name__ == '__main__':
    main()
