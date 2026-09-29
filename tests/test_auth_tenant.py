import pytest

@pytest.mark.skip(reason="TODO: viewer of demoA must not see demoB events")
def test_viewer_cannot_see_other_tenant():
    ...
