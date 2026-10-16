class SummonerNotFound(BaseException):
    pass


class SummonerGamesNotFound(BaseException):
    pass


class SummonerRankInfoNotFound(BaseException):
    pass


class SummonerNotInGame(BaseException):
    pass


class RetryMaximumAttempts(BaseException):
    pass


class SgpServerUnavailable(Exception):
    """
    SGP(GAMHS) 战绩接口返回 5xx

    与服务端正常返回、只是「没有对局」的 `SummonerGamesNotFound` 不同,
    这属于服务端暂时性故障(如 503 Service Unavailable), 不代表该召唤师真的没有战绩,
    因此需要单独区分, 以便界面给出准确提示而不是静默空白
    """

    def __init__(self, status=503):
        super().__init__(f"SGP server returned {status}")
        self.status = status
