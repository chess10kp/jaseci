import from jaclang.cli.console { console }
glob JAC_LOGO = '   _\n  (_) __ _  ___\n  | |/ _` |/ __|\n  | | (_| | (__\n _/ |\\__,_|\\___|\n|__/',
     JAC_DOCS_URL = 'https://www.jaclang.org/docs',
     JAC_DISCORD_URL = 'https://discord.gg/6j3QNdtcN6',
     JAC_GITHUB_URL = 'https://github.com/Jaseci-Labs/jaseci',
     JAC_ISSUES_URL = 'https://github.com/Jaseci-Labs/jaseci/issues';

def print_logo(version: str, platform_short: str | None = None) {
    logo_lines = JAC_LOGO.split('\n');
    console.print(logo_lines[0], style='bold cyan');
    console.print((logo_lines[1] + '     Jac Language'), style='bold cyan');
    console.print(logo_lines[2], style='bold cyan');
    console.print((logo_lines[3] + f"     Version:  {version}"), style='cyan');
    console.print(logo_lines[4], style='cyan');
    last = logo_lines[5];
    if platform_short {
        last += f"                Platform: {platform_short}";
    }
    console.print(last, style='cyan');
}
