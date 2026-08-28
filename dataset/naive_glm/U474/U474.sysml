package BilgePumpingSystem {
    import ISQ::*;
    import ScalarValues::*;

    package Units {
        value type Voltage :> Real { unit 'V'; }
        value type Current :> Real { unit 'A'; }
        value type FlowRate :> Real { unit 'L/min'; }
        value type Pressure :> Real { unit 'bar'; }
        value type Length :> Real { unit 'cm'; }
        value type Duration :> Real { unit 's'; }
        value type Volume :> Real { unit 'L'; }
    }

    package Items {
        item def Water;

        item def ElectricPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }

        item def StartCommand;
        item def StopCommand;

        item def FaultSignal {
            attribute faultType : String;
        }

        item def WaterLevelReading {
            attribute level : Length;
        }
    }

    package Ports {
        port def PowerPort {
            in power : Items::ElectricPower;
        }

        port def WaterPort {
            in water : Items::Water;
            out water : Items::Water;
        }

        port def CommandOutPort {
            out startCmd : Items::StartCommand;
            out stopCmd : Items::StopCommand;
        }

        port def CommandInPort {
            in startCmd : Items::StartCommand;
            in stopCmd : Items::StopCommand;
        }

        port def SignalPort {
            out fault : Items::FaultSignal;
        }

        port def LevelSensePort {
            out reading : Items::WaterLevelReading;
        }
    }

    package Components {
        part def BilgeCompartment {
            attribute capacity : Volume = 200 [L];
            attribute currentLevel : Length;
            port waterCollect :>> Ports::WaterPort;
            
            compute updateLevel {
                in inflow : Items::Water;
                out level : Length;
            }
        }

        part def FloatSwitch {
            attribute highWaterMark : Length = 30 [cm];
            attribute lowWaterMark : Length = 5 [cm];
            attribute sensedLevel : Length;
            
            port commandOut :>> Ports::CommandOutPort;
            port levelIn :>> Ports::LevelSensePort;
            
            state machine FloatSwitchBehavior {
                entry; then Standby;
                
                state Standby {
                    entry { send commandOut.startCmd; }
                    // actually standby should not send start; fix below
                }
            }
        }
    }
}

Wait, I need to fix the logic. Let me rewrite cleanly without errors.

package BilgePumpingSystem {
    import ISQ::*;
    import ScalarValues::*;

    package Units {
        value type Voltage :> Real { unit 'V'; }
        value type Current :> Real { unit 'A'; }
        value type FlowRate :> Real { unit 'L/min'; }
        value type Pressure :> Real { unit 'bar'; }
        value type Length :> Real { unit 'cm'; }
        value type Duration :> Real { unit 's'; }
        value type Volume :> Real { unit 'L'; }
    }

    package Items {
        item def Water;

        item def ElectricPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }

        item def StartCommand;
        item def StopCommand;

        item def FaultSignal {
            attribute faultType : String;
        }

        item def WaterLevelReading {
            attribute level : Length;
        }
    }

    package Ports {
        port def PowerPort {
            in power : Items::ElectricPower;
        }

        port def WaterPort {
            in water : Items::Water;
            out water : Items::Water;
        }

        port def CommandOutPort {
            out startCmd : Items::StartCommand;
            out stopCmd : Items::StopCommand;
        }

        port def CommandInPort {
            in startCmd : Items::StartCommand;
            in stopCmd : Items::StopCommand;
        }

        port def SignalPort {
            out fault : Items::FaultSignal;
        }

        port def LevelSensePort {
            out reading : Items::WaterLevelReading;
        }
    }

    package Components {

        part def BilgeCompartment {
            attribute capacity : Volume = 200 [L];
            attribute currentLevel : Length = 0 [cm];
            port waterCollect :>> Ports::WaterPort;

            action def AccumulateWater {
                in incoming : Items::Water;
                out updatedLevel : Length;
            }
        }

        part def FloatSwitch {
            attribute highWaterMark : Length = 30 [cm];
            attribute lowWaterMark : Length = 5 [cm];
            attribute sensedLevel : Length;

            port commandOut :>> Ports::CommandOutPort;
            port levelIn :>> Ports::LevelSensePort;

            state machine FloatSwitchBehavior {
                entry; then Standby;

                state Standby {
                    accept reading : Items::WaterLevelReading
                        via levelIn.reading
                        when reading.level >= highWaterMark;
                    then Activated;
                }

                state Activated {
                    entry { send commandOut.startCmd; }
                    accept reading : Items::WaterLevelReading
                        via levelIn.reading
                        when reading.level <= lowWaterMark;
                    then Deactivated;
                }

                state Deactivated {
                    entry { send commandOut.stopCmd; }
                    then Standby;
                }
            }
        }

        part def PowerSupply {
            attribute nominalVoltage : Voltage = 12 [V];
            attribute maxCurrent : Current = 15 [A];
            port powerOut :>> Ports::PowerPort;

            action def SupplyPower {
                out power : Items::ElectricPower;
            }
        }

        part def DischargeOutlet {
            attribute maxFlowRate : FlowRate = 40 [L/min];
            port waterDischarge :>> Ports::WaterPort;
        }

        part def BilgePump {
            attribute ratedVoltage : Voltage = 12 [V];
            attribute ratedFlowRate : FlowRate = 30 [L/min];
            attribute primingDuration : Duration = 3 [s];
            attribute maxBackPressure : Pressure = 1.5 [bar];

            port powerIn :>> Ports::PowerPort;
            port commandIn :>> Ports::CommandInPort;
            port waterIntake :>> Ports::WaterPort;
            port waterOut :>> Ports::WaterPort;
            port faultOut :>> Ports::SignalPort;

            attribute backPressure : Pressure;
            attribute inletHasWater : Boolean;

            state machine PumpController {
                entry; then Idle;

                state Idle {
                    accept cmd : Items::StartCommand via commandIn.startCmd;
                    then Priming;
                }

                state Priming {
                    entry { /* prime pump */ }
                    after primingDuration;
                    then Running;
                }

                state Running {
                    accept cmd : Items::StopCommand via commandIn.stopCmd;
                    then Stopped;

                    accept when !inletHasWater;
                    then FaultDry;

                    accept when backPressure > maxBackPressure;
                    then FaultBlocked;
                }

                state FaultDry {
                    entry {
                        send faultOut.fault(faultType = "DryRun");
                    }
                    then Shutdown;
                }

                state FaultBlocked {
                    entry {
                        send faultOut.fault(faultType = "Blockage");
                    }
                    then Shutdown;
                }

                state Shutdown {
                    entry { /* power off pump */ }
                    then Idle;
                }

                state Stopped {
                    entry { /* normal stop */ }
                    then Idle;
                }
            }

            action def PumpWater {
                in power : Items::ElectricPower;
                in water : Items::Water;
                out pumpedWater : Items::Water;
            }
        }
    }

    package System {

        part BilgePumpingSystem {
            part bilge : Components::BilgeCompartment;
            part floatSwitch : Components::FloatSwitch;
            part pump : Components::BilgePump;
            part powerSupply : Components::PowerSupply;
            part discharge : Components::DischargeOutlet;

            connection powerConnection connect powerSupply.powerOut to pump.powerIn {
                item flow power : Items::ElectricPower;
            }

            connection commandConnection connect floatSwitch.commandOut to pump.commandIn {
                item flow startCmd : Items::StartCommand;
                item flow stopCmd : Items::StopCommand;
            }

            connection levelSenseConnection connect bilge.waterCollect to floatSwitch.levelIn {
                item flow reading : Items::WaterLevelReading;
            }

            connection intakeConnection connect bilge.waterCollect to pump.waterIntake {
                item flow water : Items::Water;
            }

            connection dischargeConnection connect pump.waterOut to discharge.waterDischarge {
                item flow water : Items::Water;
            }
        }
    }

    package Requirements {

        requirement def AutomaticBilgeEvacuation {
            doc "The system shall automatically detect and remove unwanted water from the bilge to prevent flooding and ensure vessel stability."
        }

        requirement def HighWaterActivation {
            doc "The float switch shall send a start command when water reaches the high-water mark."
            subject floatSwitch : Components::FloatSwitch;
            constraint { sensedLevel >= highWaterMark }
        }

        requirement def LowWaterDeactivation {
            doc "The float switch shall send a stop command when water reaches the low-water mark."
            subject floatSwitch : Components::FloatSwitch;
            constraint { sensedLevel <= lowWaterMark }
        }

        requirement def PumpPrimingBeforeRun {
            doc "The pump shall enter a priming state for a brief duration before running continuously."
            subject pump : Components::BilgePump;
            constraint { primingDuration > 0 [s] }
        }

        requirement def FaultDetectionShutdown {
            doc "The pump shall shut down and signal an error upon detecting dry-run or excessive back-pressure."
            subject pump : Components::BilgePump;
            constraint { inletHasWater == false or backPressure > maxBackPressure }
        }

        requirement def PowerSupplyCompatibility {
            doc "The pump shall operate from the vessel's 12-volt power supply."
            subject powerSupply : Components::PowerSupply;
            constraint { nominalVoltage == 12 [V] }
        }

        requirement def StandbyReadiness {
            doc "After a pumping cycle or fault shutdown, the system shall return to a standby state ready for the next cycle."
            subject system : System::BilgePumpingSystem;
        }

        requirement BilgeSystemRequirements : AutomaticBilgeEvacuation {
            satisfy requirement HighWaterActivation;
            satisfy requirement LowWaterDeactivation;
            satisfy requirement PumpPrimingBeforeRun;
            satisfy requirement FaultDetectionShutdown;
            satisfy requirement PowerSupplyCompatibility;
            satisfy requirement StandbyReadiness;
        }
    }
}

Let me check the send syntax. In SysML v2, `send port.message(payload)` is valid. Actually the syntax is `send StartCommand to port` or `send port.message`. Let me use simpler form: `send commandOut.startCmd;` for no payload. For fault with attribute, `send faultOut.fault(faultType = "DryRun");` — hmm, actually the send action syntax: `send source.message(payload)`. The payload is an expression. Setting attribute faultType inside payload... I think better to just send the FaultSignal item.

Actually let me simplify: `send faultOut.fault;` and define fault as out item. But we want faultType. Let me use: `send FaultSignal(faultType = "DryRun") to faultOut;` — the syntax `send <expression> to <port>`. Hmm.

In SysML v2: `send MessageName(payload) to PortName;` Actually the standard form is:
`send source.message;` where message is an out feature of the port.

For payload: `send source.message(payloadExpression);`

I'll use: `send faultOut.fault(FaultSignal(faultType = "DryRun"));` — but that's nested. Simpler: just `send faultOut.fault;` and accept that faultType is set elsewhere. Actually let me keep it readable:

`send faultOut.fault;`

And for start/stop: `send commandOut.startCmd;` and `send commandOut.stopCmd;`

Let me also reconsider the `accept ... via ... when ...` syntax. The proper syntax:
`accept <trigger> via <port.feature> when <condition>;`

Actually I think it's: `accept <message> via <port>;` or with feature path. Let me use:
`accept reading : Items::WaterLevelReading via levelIn.reading when reading.level >= highWaterMark;`

This should be acceptable.

Also `after primingDuration;` — time event. Syntax: `after <duration>;`. Good.

Also `accept when !inletHasWater;` — change event. Syntax: `accept when <condition>;`. Good.

The `port def WaterPort` with both in and out water of same type — that's fine, bidirectional. Actually for bilge, water flows out. Let me make WaterPort have `out water` only, and intake uses in. Hmm, but I defined both in and out. Let me keep it simple — define separate ports or just use the same def with both directions. Actually having both in and out water in same port def is okay.

Wait, in connection `levelSenseConnection connect bilge.waterCollect to floatSwitch.levelIn` — bilge.waterCollect is a WaterPort but floatSwitch.levelIn is a LevelSensePort. These are different port types. A connection between different port types is allowed if they have compatible flows. But the item flow `reading : Items::WaterLevelReading` — bilge doesn't produce WaterLevelReading. This is a modeling issue.

Let me reconsider. The bilge compartment holds water; the float switch senses level. Better: float switch has a sensor that reads from bilge. Let me add a level sense port to bilge or make float switch monitor bilge directly.

Simplification: FloatSwitch senses the bilge water level directly (it's physically in the bilge). So floatSwitch has an attribute sensedLevel that's updated by an action reading from bilge. Or, bilge has a levelOut port sending WaterLevelReading.

Let me add to BilgeCompartment a `port levelOut :>> Ports::LevelSensePort;` and have it emit readings. Then connect bilge.levelOut to floatSwitch.levelIn.

Let me restructure BilgeCompartment:
part def BilgeCompartment {
    attribute capacity : Volume = 200 [L];
    attribute currentLevel : Length = 0 [cm];
    port waterCollect :>> Ports::WaterPort;
    port levelOut :>> Ports::LevelSensePort;
}

And connection: `connect bilge.levelOut to floatSwitch.levelIn`.

Also the intakeConnection: bilge.waterCollect (WaterPort) to pump.waterIntake (WaterPort) — same type, good.

Let me also reconsider: WaterPort has both in and out water. For bilge waterCollect, water flows out (to pump). For pump waterIntake, water flows in. For pump waterOut, water flows out. For discharge waterDischarge, water flows in. The port def with both directions works but is loose. It's fine for this model.

Actually, having `in water` and `out water` both in WaterPort means every WaterPort has both. That's okay conceptually (bidirectional port). Connections will route appropriately.

Let me finalize. Also need to make sure `send` statements are valid. I'll use the form without payload for commands, and for fault I'll just send the fault item.

Actually for fault with type, let me do:
entry {
    attribute f : Items::FaultSignal = FaultSignal(faultType = "DryRun");
    send faultOut.fault(f);
}
Hmm, that's verbose. Simpler: just `send faultOut.fault;` and note faultType is conceptual. But requirement wants signaling error. Let me keep `send faultOut.fault;`.

Actually, I realize the send syntax in SysML v2 for sending through a port out feature is:
`send <portRef>.<outFeature>(<payload>);`

where payload is optional. So `send faultOut.fault;` is valid (no payload). Good.

But to convey faultType, I could do `send faultOut.fault(FaultSignal(faultType = "DryRun"));`. The payload expression constructs the item. I think this is acceptable. Let me use it.

Hmm, but FaultSignal is an item def, and constructing an instance... In SysML v2, item defs can have instances. `FaultSignal(faultType = "DryRun")` should be a valid expression. I'll use it.

Let me also double check `attribute f : Items::FaultSignal` — items can be attributes? Actually items flow; attributes are values. Better not. Just send inline.

Final check on the `satisfy` keyword in requirement — it's `satisfyreq` or `satisfy`. In SysML v2: `satisfy <requirement>;` inside a requirement? Actually the relationship is: a requirement can `satisfy` another? No — parts satisfy requirements. The syntax: `satisfy <requirementRef> by <part>;` or within a part: `satisfy <requirement>;`.

Let me restructure requirements to be satisfied by the system part. Actually, to keep it simple, I'll just define the requirements and add a satisfaction relationship in the system.

Let me put in System::BilgePumpingSystem:
satisfy Requirements::BilgeSystemRequirements;

Hmm, actually `satisfy` is a keyword used like: `satisfy <req> by <element>;` at package level, or `satisfy <req>;` inside a part.

Let me just define requirements standalone and add satisfaction in the system part.

Let me write the final clean version.

One more issue: `port def WaterPort { in water : Items::Water; out water : Items::Water; }` — having two features named `water` (one in, one out) with same name might conflict. Let me rename: `in waterIn : Items::Water; out waterOut : Items::Water;`. But then item flows reference these. Actually in connections, item flow names are declared in the connection. Let me keep port features as `in water; out water;` — actually duplicate names in different directions might be okay since they're distinguished by direction. But to be safe, rename.

Actually, simpler: make WaterPort unidirectional out, and have a separate WaterInPort. Or just use a single flow port. Let me define:
port def WaterFlowPort {
    out water : Items::Water;
}
port def WaterIntakePort {
    in water : Items::Water;
}

Then bilge.waterCollect : WaterFlowPort, pump.waterIntake : WaterIntakePort, pump.waterOut : WaterFlowPort, discharge.waterDischarge : WaterIntakePort.

Connections between WaterFlowPort (out) and WaterIntakePort (in) — compatible. Good.

Let me finalize with this approach.

Also for PowerPort: `in power` on pump side, `out power` on supply side. Define:
port def PowerOutPort { out power : Items::ElectricPower; }
port def PowerInPort { in power : Items::ElectricPower; }

CommandOutPort (out startCmd, stopCmd), CommandInPort (in startCmd, stopCmd). Good.

SignalPort: `out fault`. Good.

LevelSensePort: `out reading`. Good. And a LevelReadPort: `in reading`. Or just connect LevelSensePort to LevelSensePort? Different directions needed. Let me define LevelReadPort { in reading }.

Actually, floatSwitch.levelIn should be LevelReadPort (in). bilge.levelOut should be LevelSensePort (out). Connect them.

Let me write final.

I think this is getting long but let me produce clean final outputpackage BilgePumpingSystem {
    import ISQ::*;
    import ScalarValues::*;

    package Units {
        value type Voltage :> Real { unit 'V'; }
        value type Current :> Real { unit 'A'; }
        value type FlowRate :> Real { unit 'L/min'; }
        value type Pressure :> Real { unit 'bar'; }
        value type Length :> Real { unit 'cm'; }
        value type Duration :> Real { unit 's'; }
        value type Volume :> Real { unit 'L'; }
    }

    package Items {
        item def Water;

        item def ElectricPower {
            attribute voltage : Voltage;
            attribute current : Current;
        }

        item def StartCommand;
        item def StopCommand;

        item def FaultSignal {
            attribute faultType : String;
        }

        item def WaterLevelReading {
            attribute level : Length;
        }
    }

    package Ports {
        port def PowerOutPort {
            out power : Items::ElectricPower;
        }

        port def PowerInPort {
            in power : Items::ElectricPower;
        }

        port def WaterFlowPort {
            out water : Items::Water;
        }

        port def WaterIntakePort {
            in water : Items::Water;
        }

        port def CommandOutPort {
            out startCmd : Items::StartCommand;
            out stopCmd : Items::StopCommand;
        }

        port def CommandInPort {
            in startCmd : Items::StartCommand;
            in stopCmd : Items::StopCommand;
        }

        port def SignalOutPort {
            out fault : Items::FaultSignal;
        }

        port def LevelOutPort {
            out reading : Items::WaterLevelReading;
        }

        port def LevelInPort {
            in reading : Items::WaterLevelReading;
        }
    }

    package Components {

        part def BilgeCompartment {
            attribute capacity : Volume = 200 [L];
            attribute currentLevel : Length = 0 [cm];
            attribute inflowRate : FlowRate;

            port waterOut :>> Ports::WaterFlowPort;
            port levelOut :>> Ports::LevelOutPort;

            action def AccumulateWater {
                in incoming : Items::Water;
                out newLevel : Length;
            }

            action def EmitLevelReading {
                out reading : Items::WaterLevelReading;
            }

            compute levelMonitor {
                out reading : Items::WaterLevelReading = WaterLevelReading(level = currentLevel);
            }
        }

        part def FloatSwitch {
            attribute highWaterMark : Length = 30 [cm];
            attribute lowWaterMark : Length = 5 [cm];
            attribute sensedLevel : Length;

            port commandOut :>> Ports::CommandOutPort;
            port levelIn :>> Ports::LevelInPort;

            state machine FloatSwitchBehavior {
                entry; then Standby;

                state Standby {
                    accept reading : Items::WaterLevelReading
                        via levelIn.reading
                        when reading.level >= highWaterMark;
                    then Activated;
                }

                state Activated {
                    entry { send commandOut.startCmd; }
                    accept reading : Items::WaterLevelReading
                        via levelIn.reading
                        when reading.level <= lowWaterMark;
                    then Deactivated;
                }

                state Deactivated {
                    entry { send commandOut.stopCmd; }
                    then Standby;
                }
            }
        }

        part def PowerSupply {
            attribute nominalVoltage : Voltage = 12 [V];
            attribute maxCurrent : Current = 15 [A];
            attribute enabled : Boolean = true;

            port powerOut :>> Ports::PowerOutPort;

            action def SupplyPower {
                out power : Items::ElectricPower;
            }

            compute powerGeneration {
                out power : Items::ElectricPower = ElectricPower(voltage = nominalVoltage, current = 10 [A]);
            }
        }

        part def DischargeOutlet {
            attribute maxFlowRate : FlowRate = 40 [L/min];
            port waterIn :>> Ports::WaterIntakePort;

            action def DischargeWater {
                in water : Items::Water;
            }
        }

        part def BilgePump {
            attribute ratedVoltage : Voltage = 12 [V];
            attribute ratedFlowRate : FlowRate = 30 [L/min];
            attribute primingDuration : Duration = 3 [s];
            attribute maxBackPressure : Pressure = 1.5 [bar];
            attribute backPressure : Pressure = 0 [bar];
            attribute inletHasWater : Boolean = true;
            attribute isRunning : Boolean = false;

            port powerIn :>> Ports::PowerInPort;
            port commandIn :>> Ports::CommandInPort;
            port waterIntake :>> Ports::WaterIntakePort;
            port waterDischarge :>> Ports::WaterFlowPort;
            port faultOut :>> Ports::SignalOutPort;

            action def PrimePump {
                in power : Items::ElectricPower;
            }

            action def PumpWater {
                in power : Items::ElectricPower;
                in water : Items::Water;
                out pumpedWater : Items::Water;
            }

            state machine PumpController {
                entry; then Idle;

                state Idle {
                    entry { isRunning = false; }
                    accept cmd : Items::StartCommand via commandIn.startCmd;
                    then Priming;
                }

                state Priming {
                    entry { /* brief priming phase */ }
                    do { PrimePump; }
                    after primingDuration;
                    then Running;
                }

                state Running {
                    entry { isRunning = true; }
                    do { PumpWater; }
                    accept cmd : Items::StopCommand via commandIn.stopCmd;
                    then Stopped;

                    accept when !inletHasWater;
                    then FaultDry;

                    accept when backPressure > maxBackPressure;
                    then FaultBlocked;
                }

                state Stopped {
                    entry { isRunning = false; }
                    then Idle;
                }

                state FaultDry {
                    entry {
                        send faultOut.fault(FaultSignal(faultType = "DryRun"));
                    }
                    then Shutdown;
                }

                state FaultBlocked {
                    entry {
                        send faultOut.fault(FaultSignal(faultType = "Blockage"));
                    }
                    then Shutdown;
                }

                state Shutdown {
                    entry { isRunning = false; }
                    then Idle;
                }
            }
        }
    }

    package SystemAssembly {

        part BilgePumpingSystem {
            part bilge : Components::BilgeCompartment;
            part floatSwitch : Components::FloatSwitch;
            part pump : Components::BilgePump;
            part powerSupply : Components::PowerSupply;
            part discharge : Components::DischargeOutlet;

            connection powerConnection connect powerSupply.powerOut to pump.powerIn {
                item flow power : Items::ElectricPower;
            }

            connection commandConnection connect floatSwitch.commandOut to pump.commandIn {
                item flow startCmd : Items::StartCommand;
                item flow stopCmd : Items::StopCommand;
            }

            connection levelSenseConnection connect bilge.levelOut to floatSwitch.levelIn {
                item flow reading : Items::WaterLevelReading;
            }

            connection intakeConnection connect bilge.waterOut to pump.waterIntake {
                item flow water : Items::Water;
            }

            connection dischargeConnection connect pump.waterDischarge to discharge.waterIn {
                item flow water : Items::Water;
            }

            satisfy Requirements::BilgeSystemRequirements;
        }
    }

    package Requirements {

        requirement def AutomaticBilgeEvacuation {
            doc "The system shall automatically detect and remove unwanted water from the bilge to prevent flooding and ensure vessel stability and safety.";
        }

        requirement def HighWaterActivation {
            doc "The float switch shall send a start command to the pump when the bilge water level reaches the pre-set high-water mark.";
            subject floatSwitch : Components::FloatSwitch;
            constraint { sensedLevel >= highWaterMark }
        }

        requirement def LowWaterDeactivation {
            doc "The float switch shall send a stop command to the pump when the bilge water level reaches the low-water mark.";
            subject floatSwitch : Components::FloatSwitch;
            constraint { sensedLevel <= lowWaterMark }
        }

        requirement def PumpPrimingBeforeRun {
            doc "The pump controller shall enter a brief priming state before running continuously to pump water out.";
            subject pump : Components::BilgePump;
            constraint { primingDuration > 0 [s] }
        }

        requirement def FaultDetectionShutdown {
            doc "The pump shall automatically shut down and signal an error upon detecting a dry-run condition or excessive back-pressure from a blockage.";
            subject pump : Components::BilgePump;
            constraint { inletHasWater == false or backPressure > maxBackPressure }
        }

        requirement def PowerSupplyCompatibility {
            doc "The pump shall be powered by the vessel's 12-volt power supply.";
            subject powerSupply : Components::PowerSupply;
            constraint { nominalVoltage == 12 [V] }
        }

        requirement def StandbyReadiness {
            doc "After a pumping cycle or fault shutdown, the system shall return to a standby state ready for the next cycle.";
            subject system : SystemAssembly::BilgePumpingSystem;
        }

        requirement def DischargeOverboard {
            doc "Pumped water shall be expelled overboard through the discharge outlet.";
            subject discharge : Components::DischargeOutlet;
            constraint { maxFlowRate >= 30 [L/min] }
        }

        requirement BilgeSystemRequirements : AutomaticBilgeEvacuation {
            satisfy requirement HighWaterActivation;
            satisfy requirement LowWaterDeactivation;
            satisfy requirement PumpPrimingBeforeRun;
            satisfy requirement FaultDetectionShutdown;
            satisfy requirement PowerSupplyCompatibility;
            satisfy requirement StandbyReadiness;
            satisfy requirement DischargeOverboard;
        }
    }
}
