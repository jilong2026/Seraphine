"""
国服战绩本地缓存

背景: 国服的战绩接口(``/match-history-query/...``)会返回 5xx(服务端超时),
此时生涯页与搜索页会一片空白。官方客户端同样取不到数据, 但它有一份本地缓存
(客户端日志中的 ``MatchHistoryCache``), 因此界面上仍然能看到上次的对局记录。

这里做同样的事: 把 SGP 返回的**原始**对局数据落盘, 服务端不可用时再取出来,
交给同一套 ``parseGamesDataFromSGP`` 解析后展示。

之所以缓存原始数据而不是解析结果: 解析结果里含召唤师技能/装备/符文的**本地图标
路径**, 直接复用会把旧版本的资源路径固化下来; 而原始数据是纯 JSON, 每次读取都
重新解析, 图标也会重新解析。

缓存按 puuid 分开存放::

    %APPDATA%\\Seraphine\\match_history_cache\\{puuid}.json

注意: 缓存只用于「服务端暂时不可用」时的降级展示, 不会掩盖错误 ——
取到缓存时界面会明确提示当前展示的是缓存数据。
"""

import json
import os
import time

from ..common.config import LOCAL_PATH
from ..common.logger import logger

TAG = "GamesCache"

# 每个召唤师最多缓存多少局(够生涯页/搜索页首屏使用即可)
MAX_CACHED_GAMES = 40

CACHE_DIR = os.path.join(LOCAL_PATH, "match_history_cache")


def _cachePath(puuid):
    return os.path.join(CACHE_DIR, f"{puuid}.json")


def saveGames(puuid, rawGames):
    """
    保存 SGP 原始对局列表

    Args:
        puuid (str): 召唤师 PUUID
        rawGames (list): SGP 返回的原始对局列表(元素为 ``{"json": {...}}`` 包装),
                         @see connector.getSummonerGamesByPuuidViaSGP

    NOTE 写失败只记日志, 不影响正常流程
    """
    if not puuid or not rawGames:
        return

    try:
        os.makedirs(CACHE_DIR, exist_ok=True)

        payload = {
            "puuid": puuid,
            "updatedAt": int(time.time() * 1000),
            "games": list(rawGames)[:MAX_CACHED_GAMES],
        }

        # 先写临时文件再替换, 避免写一半时程序退出留下损坏的缓存
        tmpPath = _cachePath(puuid) + ".tmp"
        with open(tmpPath, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)

        os.replace(tmpPath, _cachePath(puuid))
    except Exception as e:
        logger.warning(f"写入战绩缓存失败: {e!r}", TAG)


def loadGames(puuid):
    """
    读出缓存的 SGP 原始对局列表

    Args:
        puuid (str): 召唤师 PUUID

    Returns:
        list: 原始对局列表; 没有缓存或缓存损坏时返回空列表

    NOTE 这里不做过期丢弃: 服务端不可用时, 显示"上次的战绩"也好过一片空白,
         界面会提示这是缓存数据
    """
    if not puuid:
        return []

    try:
        with open(_cachePath(puuid), "r", encoding="utf-8") as f:
            payload = json.load(f)
    except FileNotFoundError:
        return []
    except Exception as e:
        logger.warning(f"读取战绩缓存失败: {e!r}", TAG)
        return []

    games = payload.get("games")
    if not isinstance(games, list):
        return []

    logger.info(f"命中战绩缓存 {puuid}, {len(games)} 局", TAG)
    return games
