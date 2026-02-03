#!/usr/bin/env python3
import sys
import json

def parse_env(content):
    result = {}
    for line in content.strip().split('\n'):
        line = line.strip()
        # 빈 줄이나 주석 무시
        if not line or line.startswith('#'):
            continue
        # KEY=VALUE 파싱
        if '=' in line:
            key, value = line.split('=', 1)
            # 따옴표 제거
            value = value.strip().strip('"').strip("'")
            result[key.strip()] = value
    return result

if __name__ == '__main__':
    # 터미널에서 직접 실행할 때만 안내 메시지 출력
    if sys.stdin.isatty():
        print("=== .env to JSON 변환기 ===")
        print(".env 내용을 붙여넣고 Ctrl+D (Mac/Linux) 또는 Ctrl+Z (Windows)로 종료하세요.")
        print("-" * 30)

    content = sys.stdin.read()

    if not content.strip():
        print("입력이 없습니다.", file=sys.stderr)
        sys.exit(1)

    result = parse_env(content)

    if sys.stdin.isatty():
        print("-" * 30)
        print("결과:")

    print(json.dumps(result, indent=2, ensure_ascii=False))
