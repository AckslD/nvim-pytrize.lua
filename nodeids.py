import json
from pathlib import Path
from typing import List, Dict
from operator import attrgetter
from dataclasses import dataclass
from collections import defaultdict

PYTEST_CACHE_DIRNAME = '.pytest_cache'
PYTEST_NODEIDS_RELPATH = Path(PYTEST_CACHE_DIRNAME) / 'v' / 'cache' / 'nodeids'


def is_root_dir(dir: Path) -> bool:
    return PYTEST_CACHE_DIRNAME in set(map(attrgetter('name'), dir.iterdir()))


def get_root_dir(basedir: Path) -> Path:
    dir = basedir
    while not is_root_dir(dir):
        if dir == dir.parent:
            raise RuntimeError("couldn't find the pytest root dir")
        dir = dir.parent
    return dir


def get_nodeids_path(basedir: Path) -> Path:
    root_dir = get_root_dir(basedir)
    return root_dir / PYTEST_NODEIDS_RELPATH


def get_raw_nodeids(basedir: Path) -> List[str]:
    nodeids_path = get_nodeids_path(basedir)
    with nodeids_path.open() as f:
        nodeids = json.load(f)
    return nodeids


def get_nodeids(basedir: Path) -> Dict[str, Dict[str, List['NodeID']]]:
    nodeids = defaultdict(lambda: defaultdict(list))
    for raw_nodeid in get_raw_nodeids(basedir):
        nodeid = NodeID.from_str(raw_nodeid)
        nodeids[nodeid.file][nodeid.function].append(nodeid)
    return {k: dict(v) for k, v in nodeids.items()}


def get_param_values(file: str, params: List[str]) -> Dict[str, Dict[str, List[str]]]:
    nodeids = get_nodeids(Path(file.parent)
    values_per_func = {}
    for func_name, nids in nodeids.get(file, {}).items():
        unique_values_per_param = defaultdict(dict)
        for nodeid in nids:
            values = nodeid.params
            for param, value in zip(params, values):
                unique_values_per_param[param][value] = True
        values_per_func[func_name] = {param: list(values) for param, values in unique_values_per_param.items()}
    return values_per_func



@dataclass
class NodeID:
    file: str
    function: str
    params: List[str]

    @staticmethod
    def from_str(s: str) -> 'NodeID':
        file, rest = s.split('::')
        function, rest = rest.split('[')
        rest = rest.replace(']', '')
        params = rest.split('-')
        return NodeID(
            file=file,
            function=function,
            params=params,
        )
