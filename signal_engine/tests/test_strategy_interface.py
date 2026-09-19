from signal_engine.strategies.momentum import MomentumStrategy


def test_strategy_has_generate_signal() -> None:
    strategy = MomentumStrategy()
    assert hasattr(strategy, "analyze")
    assert hasattr(strategy, "generateSignal")
