# Product Mission

## Problem

Existing GURPS virtual tabletop solutions (like Foundry VTT with the unofficial GURPS system) prioritize flexibility over automation, leaving combat resolution largely manual. This negates the benefit of using a computer — the player must still track movement limits, maneuver constraints, attack resolution, and hit locations by hand. The underlying data structures in these tools also lack fundamental relationships (e.g., no link between an attack and the equipment used for it, no concept of what's in a character's hands), making it impractical to build proper automation on top of them.

## Target Users

Personal use — a GURPS player/GM who wants to simulate tactical combat with faithful, automated rules enforcement on a local machine.

## Solution

An XCOM-style turn-based tactical combat game built in Godot 4 that implements GURPS rules with full automation. Unlike flexible-but-manual VTTs, this tool enforces rules automatically: movement is constrained to the hex grid with visual feedback on how distance affects available maneuvers, combat resolution handles rolls and modifiers instantly, and character data imports directly from GCS/GCA. The XCOM-inspired interface makes the turn flow intuitive — click to move, see your remaining options update in real time, select a maneuver, and let the computer handle the crunch. Because it's a purpose-built application rather than a VTT plugin, it can go beyond tabletop limitations — potentially using physics-based ballistics for realistic bullet trajectories and hit location determination instead of random rolls.
