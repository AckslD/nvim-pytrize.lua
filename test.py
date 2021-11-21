import pytest


@pytest.mark.parametrize('i', range(10))
@pytest.mark.parametrize('a, b, c', [
    ({}, 'b', None),
    ({}, 'b', {}),
])
@pytest.mark.parametrize('x', [
    None,
    None,
    None,
])
def test(i, a, b, c, x):
    assert True
