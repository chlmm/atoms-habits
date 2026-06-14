"""
运行全部测试（每个测试独立准备数据，互不依赖）
"""

import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

from test_r2_create import test_r2_create
from test_r2_demo import test_r2_demo
from test_r4_exec import test_r4
from test_r5_milestone import test_r5
from test_r6_review import test_r6_review
from test_r7_identity import test_r7_identity


def main():
    passed = 0
    failed = 0

    tests = [
        ("R2-A 自建流程", test_r2_create),
        ("R2-B 引导模式", test_r2_demo),
        ("R4 每日习惯打卡", test_r4),
        ("R5 里程碑推进", test_r5),
        ("R6 每周回顾", test_r6_review),
        ("R7 身份洞察", test_r7_identity),
    ]

    for name, fn in tests:
        print(f"\n{'═' * 40}")
        print(f"  {name}")
        print(f"{'═' * 40}")
        try:
            fn()
            passed += 1
        except Exception as e:
            print(f"\n✗ 测试失败: {e}")
            failed += 1

    print(f"\n{'═' * 40}")
    print(f"  总计: {passed} 通过, {failed} 失败")
    print(f"{'═' * 40}")

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
