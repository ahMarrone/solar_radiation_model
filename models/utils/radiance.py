#!/usr/bin/env python

import sys
sys.path.append(".")
from netcdf import netcdf as nc
from models.helpers import to_datetime, short
from glob import glob
from itertools import groupby
import os
from functools import partial


rev_key = {}


def initialize(radiance_filename, radiation_filename, callback=lambda r: r):
    ref, _ = nc.open(radiation_filename)
    ref_radiation = nc.getvar(ref, 'globalradiation')
    with nc.loader(radiance_filename) as radiance_root:
        radiance = nc.getvar(radiance_root, 'radiance', source=ref_radiation)
        radiance[0, :] = callback(radiance[0, :])
    nc.close(ref)


def radiance(radiance_files, radiance_filename):
    if radiance_filename in rev_key:
        filename = rev_key[radiance_filename]
        initialize(radiance_filename, filename,
                   lambda r: r * 30. * 60. * 10 ** -6)
    else:
        interpolate_radiance(radiance_files, radiance_filename)


def search_closest(list_items, filename, step):
    index = list_items.index(filename)
    max_index = len(list_items) - 1
    check = lambda i: 0 <= i <= max_index
    while check(index) and list_items[index] not in rev_key:
        index = step(index)
    return list_items[index] if check(index) else None


def interpolate_radiance(radiance_files, radiance_filename):
    before = search_closest(radiance_files, radiance_filename, lambda s: s - 1)
    after = search_closest(radiance_files, radiance_filename, lambda s: s + 1)
    extrems = filter(lambda x: x, [before, after])
    if extrems:
        ref_filename = max(extrems)
        root, is_new = nc.open(map(lambda e: rev_key[e], extrems))
        radiation = nc.getvar(root, 'globalradiation')
        initialize(radiance_filename, rev_key[ref_filename],
                   lambda r: radiation[:].mean(axis=0) * 30. * 60. * 10 ** -6)
        nc.close(root)


def generate_radiance_filename(filename):
    prefix = short(filename, 0, 3)
    decimalhour = lambda t: t.hour + t.minute/60. + t.second/3600.
    slot = str(int(round(decimalhour(to_datetime(filename))*2))).zfill(2)
    suffix = short(filename, 4, 6)
    if not os.path.exists('products/radiance'):
        os.makedirs('products/radiance')
    output_filename = 'products/radiance/rad.%s.S%s.%s' % (
        prefix, slot, suffix)
    return output_filename


def complete(radiance_files):
    t_slots = set(range(20, 47))
    if radiance_files:
        prefix = short(radiance_files[0], 0, 2)
        suffix = short(radiance_files[0], -2, None)
    slot = lambda filename: int(short(filename, 4)[1:])
    to_datetime = lambda f: short(f, 2, 4)
    groups = groupby(sorted(radiance_files), to_datetime)
    for day, files_by_day in groups:
        slots_by_day = set(map(slot, list(files_by_day)))
        new_slots = t_slots - slots_by_day
        id = lambda s: '%s.S%s' % (day, str(s).zfill(2))
        output_file = lambda s: 'products/radiance/%s.%s.%s' % (
            prefix, id(s), suffix)
        radiance_files += map(output_file, new_slots)
    radiance_files.sort()
    return radiance_files


def workwith(path='products/estimated/*.nc'):
    estimated_files = glob(path)
    radiance_files = map(generate_radiance_filename, estimated_files)
    rev_key.update(dict(zip(radiance_files, estimated_files)))
    radiance_files = complete(radiance_files)
    map(partial(radiance, radiance_files), radiance_files)


if __name__ == '__main__':
    workwith()
