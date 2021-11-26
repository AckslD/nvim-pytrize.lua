# Pytrize

## Short summary
Helps navigating `pytest.mark.parametrize` entries by virtual text and jump to declaration commands, using `pytest`s cache and `treesitter`.

## What problem does this plugin solve?
`pytest` is amazing! The only thing that bothers me is if there are many entries in in the parametrization of the test.
For example if a test fails you might see for example:
```
test.py::test[None2-a1-b-c1-8]
```
Now you want to see what test case this actually corresponds to.
What I sometimes do is to go to the entries in `pytest.mark.parametrize` and count the entries until I'm at the right one.
But this is really not nice and easy to make a mistake, we should let the computer to this for us.

Enter `pytrize`.

## What does the plugin do?
Two things:
* Populates virtual text at the entries of `pytest.mark.parametrize` (see gif above) such that you can easily see which one is which.
  Done by calling `Pytrize` (and `PytrizeClear` to clear them).
  Alternatively `lua require('pytrize.api').set()` (and `lua require('pytrize.api').clear()`).
* Provides a command to jump to the corresponding entry in `pytest.mark.parametrize` based on the test-case id under the cursor (see gif above).
  Done by calling `PytrizeJump`.
  Alternatively `lua require('pytrize.api').jump()`.

## Installation
For example using [`packer`](https://github.com/wbthomason/packer.nvim):
```lua
use { -- pytrize {{{
  '~/dev/vim-plugins/nvim-pytrize.lua',
  -- uncomment if you want to lazy load
  -- cmd = {'Pytrize', 'PytrizeClear', 'PytrizeJump'},
  -- uncomment if you want to lazy load but not use the commands
  -- module = 'pytrize',
  config = 'require("pytrize").setup()',
} -- }}}
```
Requires [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter).

## Configuration
`require("pytrize").setup` takes an optional table of settings which currently have the default values:
```lua
{
    no_commands = false,
    highlight = 'LineNr',
}
```
where:
* `no_commands` can be set to `true` and the commands `Pytrize` etc won't be declared.
* `highlight` defines the highlighting used for the virtual text.

## Implementation details
* `pytest`s cache is used to find the test-case ids (eg `test.py::test[None2-a1-b-c1-8]`) which means that the tests have to be run at least ones.
  Also old ids might confuse `pytrize`, but you can clear the cache with `pytest --cache-clear`.
* `treesitter` is used to find the correct entry in `pytest.mark.parametrize`.
