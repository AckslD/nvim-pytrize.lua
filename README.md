# Pytrize

## Short summary
Helps navigating `pytest.mark.parametrize` entries by virtual text and jump to declaration commands, using `pytest`s cache and `treesitter`.

![pytrize](https://user-images.githubusercontent.com/23341710/143510539-c025925c-0e4c-4990-83ab-1c0da076c0f8.gif)

## What problem does this plugin solve?
`pytest` is amazing! The only thing that bothers me from time to time is if there are many entries in the parametrization of the test.
If a test fails you might see for example:
```
test.py::test[None2-a1-b-c1-8]
```
Now you want to see what test case this actually corresponds to.
What I sometimes do is to go to the entries in `pytest.mark.parametrize` and count the entries until I'm at the right one.
But this is really not nice and easy to make a mistake, we should let the computer do this for us.

Enter `pytrize`.

## What does the plugin do?
Two things:
* Populates virtual text at the entries of `pytest.mark.parametrize` (see gif above), such that you can easily see which one is which.
  Done by calling `Pytrize` (and `PytrizeClear` to clear them).
  Alternatively `lua require('pytrize.api').set()` (and `lua require('pytrize.api').clear()`).
* Provides a command to jump to the corresponding entry in `pytest.mark.parametrize` based on the test-case id under the cursor (see gif above).
  Done by calling `PytrizeJump`.
  Alternatively `lua require('pytrize.api').jump()`.
  See the [Input](#input)-section below for cases where the file-path is not available.

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
  preferred_input = 'telescope',
}
```
where:
* `no_commands` can be set to `true` and the commands `Pytrize` etc won't be declared.
* `highlight` defines the highlighting used for the virtual text.
* `preferred_input` which method to query input to prefer (if it's installed), see the [Input](#input)-section below.

## Details
* `pytest`s cache is used to find the test-case ids (eg `test.py::test[None2-a1-b-c1-8]`) which means that the tests have to be run at least once.
  Also old ids might confuse `pytrize`, but you can clear the cache with `pytest --cache-clear`.
* `treesitter` is used to find the correct entry in `pytest.mark.parametrize`.

## Input
In some cases the file-path is not printed by pytest, for example when a test fails when it might look something like:
```

_________________________________ test[None2-a1-b-c1-9] _________________________________
```
or similar.
If you trigger to jump to the declaration of the parameters in this case `pytrize` will find all files in the cache that matches this test-case id and if there is more than one ask you which one to jump to.
Currently three input methods are supported:
* [`telescope`](https://github.com/nvim-telescope/telescope.nvim)
  ![pytrize_input_telescope](https://user-images.githubusercontent.com/23341710/145381466-42152977-f412-425d-9ddb-cc0c4dfde4fb.gif)
* [`nui`](https://github.com/MunifTanjim/nui.nvim)
  ![pytrize_input_nui](https://user-images.githubusercontent.com/23341710/145381492-5e5abec0-c8c5-468c-90ee-b854e9d57146.gif)
* `inputlist` (neovim native)
  ![pytrize_input_builtin](https://user-images.githubusercontent.com/23341710/145381515-4afb6d1b-e6f5-4c55-bfc8-99d086f0f3b2.gif)
