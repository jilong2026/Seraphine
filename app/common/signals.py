from PyQt5.QtCore import QObject, pyqtSignal
from PyQt5.QtGui import QColor
from PyQt5.QtWidgets import QWidget


class SignalBus(QObject):
    # listener:
    tasklistNotFound = pyqtSignal()

    lolClientStarted = pyqtSignal(int)
    lolClientEnded = pyqtSignal()
    lolClientChanged = pyqtSignal(int)

    terminateListeners = pyqtSignal()

    # connector:
    lcuApiExceptionRaised = pyqtSignal(str, BaseException)
    currentSummonerProfileChanged = pyqtSignal(dict)
    gameStatusChanged = pyqtSignal(str)
    champSelectChanged = pyqtSignal(dict)
    getCmdlineError = pyqtSignal()

    # career_interface
    careerGameBarClicked = pyqtSignal(str)

    # 国服战绩: 接口 5xx 时降级展示本地缓存, 载荷为 puuid
    matchHistoryCacheUsed = pyqtSignal(str)

    # search_interface:
    gameTabClicked = pyqtSignal(QWidget)

    # jumps:
    toCareerInterface = pyqtSignal(str)
    toSearchInterface = pyqtSignal(str)

    # style:
    customColorChanged = pyqtSignal(str)

    # OPGG:
    toOpggBuildInterface = pyqtSignal(int, str, str)


signalBus = SignalBus()
