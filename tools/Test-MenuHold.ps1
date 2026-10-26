$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$policy = [regex]::Match($source, '(?s)// BEGIN MENU HOLD POLICY\s*(.*?)// END MENU HOLD POLICY')
if (-not $policy.Success) { throw 'Cannot locate the actual menu-hold policy.' }
$testBody = @'
#include <cassert>
#include <cstdio>
int main() {
    MenuHoldPolicy policy;
    assert(!policy.Observe(0, true, 42)); // Unrelated menus cannot arm it.

    policy.Arm(100);
    assert(policy.Observe(100, false, 0));
    assert(policy.Observe(1099, false, 0));
    assert(!policy.Observe(1100, false, 0)); // No menu: bounded timeout.
    assert(!policy.armed);

    policy.Arm(0);
    assert(policy.Observe(50, true, 42));
    assert(policy.Observe(15000, true, 42)); // Real menu may outlive timeout.
    assert(policy.Observe(15100, false, 0)); // Brief focus-return grace.
    assert(!policy.Observe(15150, false, 0));
    assert(!policy.armed);

    policy.Arm(0);
    assert(policy.Observe(10, true, 0)); // Transient unknown owner.
    assert(policy.Observe(20, true, 42));
    assert(!policy.Observe(30, true, 43)); // Do not follow another app's menu.

    policy.Arm(100);
    assert(policy.Observe(110, true, 42));
    policy.Arm(120); // A new explicit gesture starts a new owner lifetime.
    assert(!policy.observed && policy.owner == 0);
    assert(policy.Observe(130, true, 43));
    policy.Reset();
    assert(!policy.Observe(140, true, 43));

    std::puts("Menu-hold policy tests passed: scope, timeout, lifetime, owner change, reset.");
}
'@
$testSource = '#include <cstdint>' + "`n" + $policy.Groups[1].Value + "`n" + $testBody
$testPath = Join-Path $projectRoot 'build\menu-hold-policy-test.cpp'
$testBinary = Join-Path $projectRoot 'build\menu-hold-policy-test.exe'
[IO.File]::WriteAllText($testPath, $testSource, [Text.UTF8Encoding]::new($false))
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' '-std=c++23' '-O0' '-Wall' '-Wextra' $testPath '-o' $testBinary
if ($LASTEXITCODE -ne 0) { throw 'Policy test compilation failed.' }
& $testBinary
if ($LASTEXITCODE -ne 0) { throw "Menu-hold policy tests failed: $LASTEXITCODE" }
