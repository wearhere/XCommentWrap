# XCommentWrap

I like using single-line comment markers. I like hard-wrapping longer comments:

    // This thing does the thing and then afterwards
    // it does the other thing, which eventually
    // results in doing the last thing.

The result is nice but it's always a bit of a pain to type and maintain. I end up with a lot of inconsistent line lengths and changing text in the middle results in a lot of busy work.

This extension makes the computer do it for me, like it ought to. It hard wraps the selected lines to 80 characters, taking into account leading comment characters. It transforms this:

    // This thing does the thing
    // and
    // then afterwards it does the other thing, which eventually results in doing the last thing.

Into this:

    // This thing does the thing and then afterwards it does the other thing, which
    // eventually results in doing the last thing.

# How to use this

This hasn't yet been published to the App Store, so you'll need to build it from source. This
involves code signing it but that's actually pretty simple _and free_ nowadays! Here's a guide:

1. Clone this repository.
2. Add your iCloud account to Xcode in Preferences -> Accounts. This does _not_ need to be a paid
   developer account.
3. With the project file selected, set both build targets to use your "Personal Team" on the
   Signing and Capabilities tab.
4. Build and run the "XCommentWrap" scheme. After the XCommentWrap app launches, you can quit it.
5. Open System Preferences -> Extensions.
5. Find XCommentWrap and enable Xcode Source Editor extension

Finally, highlight some code in Xcode and choose Editor -> XCommentWrap -> Hard Wrap Comment. You can
assign a key binding to this if you like in Xcode's preferences.

# How it works

It splits each line into a leading area and a trailing area, considering a leading area to be a sequence of spaces, tabs, `/`, and `*` characters. It then concatenates the trailing areas together with spaces in between and applies a hard wrap to the resulting string. Finally, it takes the leading area from the first line and prepends it to every line.

This means it will work on a bunch of single-line comments in sequence, whether they start with `//` or `///`. It will also work on multi-line comments provided your text is not on the same line as the initial comment indicator. It will not work on multi-line comments where the first line of text directly follows the `/*`. If you want that, you'll have to build it yourself.

The extension is "paragraph-aware": if your cursor is on the first line here when you invoke the
extension

    // This thing does the thing and then afterwards it does the other thing, which then does another thing,
    // which eventually results in doing the last thing.

it'll put the overflow of the first line onto the second line, rather than its own line:

    // This thing does the thing and then afterwards it does the other thing, which
    // then does another thing, which eventually results in doing the last thing.

It'll also preserve paragraph breaks: if you've selected this entire comment block

    // This thing does the thing and then afterwards it does the other thing, which then does another thing,
    // which eventually results in doing the last thing.
    //
    // Oh and then it does some more things. And then some more things. And then it's done.

it'll produce

    // This thing does the thing and then afterwards it does the other thing, which
    // then does another thing, which eventually results in doing the last thing.
    //
    // Oh and then it does some more things. And then some more things. And then
    // it's done.

For safety's sake, the extension will no-op if you have lines of code selected. (You probably want
to wrap those at syntactic breaks like after arguments in a function call, not merely at the page
guide.)

# How to contribute

Switch the project to the XCommentWrap-extension scheme and build and run. A test version of Xcode
will open with the debugger from the real Xcode attached. This is described in more detail in
https://developer.apple.com/documentation/xcodekit/testing_your_source_editor_extension.

To get the changes to show up in the real Xcode, you'll need to relaunch it.

# License

XCommentWrap is public domain. Do what you feel like with it. If you build something cool from it, credit would be nice, but not required. It's not like a huge amount of work went into it.
