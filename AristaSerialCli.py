"""Customer CLI extension handlers for the BCIX USB serial console helper."""

import subprocess

import CliExtension
import CliExtensionMatchers
import CliMatcher
import CliParserCommon


SCRIPT = "/mnt/flash/usbserial.sh"
NAMESPACE = "bcix.serial"


def _serial_port_matcher(token, values, regex):
    def names(_mode):
        return values

    def empty_token_completions(_mode, _context):
        return [
            CliParserCommon.Completion(name, description)
            for name, description in values.items()
        ]

    return CliMatcher.DynamicNameMatcher(
        names,
        helpdesc=token,
        pattern=regex,
        extraEmptyTokenCompletionFn=empty_token_completions,
    )


CliExtensionMatchers.registerMatcher(
    "serialPort",
    _serial_port_matcher,
    requiredArgs={"values": dict, "regex": str},
)


def _run(ctx, arguments, privileged=False):
    command = ["/bin/bash", SCRIPT] + [str(argument) for argument in arguments]
    if privileged:
        command.insert(0, "/usr/bin/sudo")

    try:
        subprocess.call(command)
    except OSError as error:
        ctx.addError("Unable to run the serial helper: %s" % error)


class SerialConnect(CliExtension.CliCommandClass):
    def handler(self, ctx):
        _run(ctx, ["connect", ctx.args["<port>"]])


class SerialSetBaud(CliExtension.CliCommandClass):
    def handler(self, ctx):
        _run(
            ctx,
            ["setbaud", ctx.args["<port>"], ctx.args["<rate>"]],
            privileged=True,
        )


class SerialSetName(CliExtension.CliCommandClass):
    def handler(self, ctx):
        _run(
            ctx,
            ["setname", ctx.args["<port>"], ctx.args["<name>"]],
            privileged=True,
        )


class ShowSerial(CliExtension.ShowCommandClass):
    def handler(self, ctx):
        # No output schema is declared, so print the helper's table directly.
        _run(ctx, ["list"])


def Plugin(ctx):
    CliExtension.registerCommand("serialConnect", SerialConnect, namespace=NAMESPACE)
    CliExtension.registerCommand("serialSetBaud", SerialSetBaud, namespace=NAMESPACE)
    CliExtension.registerCommand("serialSetName", SerialSetName, namespace=NAMESPACE)
    CliExtension.registerCommand("showSerial", ShowSerial, namespace=NAMESPACE)
