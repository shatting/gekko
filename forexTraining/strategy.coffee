{
    "buy": {
        "operator": "And",
        "left": {
            "operator": "Or",
            "left": {
                "indicator": "Momentum",
                "sign": "<",
                "value": -11.08254302306765
            },
            "right": {
                "indicator": "MACD",
                "sign": "<",
                "value": -2.249905122057654
            }
        },
        "right": {
            "operator": "Or",
            "left": {
                "indicator": "RSI",
                "sign": ">",
                "value": 84411.94431826488
            },
            "right": {
                "indicator": "Momentum",
                "sign": "<",
                "value": 3.807448015912197
            }
        }
    },
    "sell": {
        "operator": "And",
        "left": {
            "operator": "Or",
            "left": {
                "indicator": "MACD_Histogram",
                "sign": ">",
                "value": -0.7017944962542784
            },
            "right": {
                "indicator": "RSI",
                "sign": "<",
                "value": 96307.11730855238
            }
        },
        "right": {
            "operator": "And",
            "left": {
                "indicator": "RSI",
                "sign": "<",
                "value": 12718.257052778095
            },
            "right": {
                "indicator": "Momentum",
                "sign": ">",
                "value": 10.33300640135731
            }
        }
    }
}
