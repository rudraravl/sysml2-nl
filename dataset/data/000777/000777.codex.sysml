package StationOutletSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage {
        :> ISQ::voltage;
        unit = V;
    }

    attribute def Current {
        :> ISQ::electricCurrent;
        unit = A;
    }

    attribute def Power {
        :> ISQ::power;
        unit = W;
    }

    attribute def Frequency {
        :> ISQ::frequency;
        unit = Hz;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = K;
    }

    attribute def Resistance {
        :> ISQ::resistance;
        unit = Ohm;
    }

    attribute def Duration {
        :> ISQ::time;
        unit = s;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        attribute power : Power;
    }

    item def GroundReference {
        attribute resistanceToEarth : Resistance;
    }

    item def ThermalStatus {
        attribute surfaceTemperature : Temperature;
        attribute terminalTemperature : Temperature;
    }

    item def FaultSignal {
        attribute overCurrentDetected : Boolean;
        attribute groundFaultDetected : Boolean;
        attribute overTemperatureDetected : Boolean;
        attribute openGroundDetected : Boolean;
    }

    item def UserCommand {
        attribute resetRequested : Boolean;
        attribute testRequested : Boolean;
    }

    item def OutletStatus {
        attribute energized : Boolean;
        attribute protected : Boolean;
        attribute availablePower : Power;
        attribute nominalVoltage : Voltage;
        attribute nominalFrequency : Frequency;
    }

    port def PowerInletPort {
        in item supply : ElectricalEnergy;
        in item ground : GroundReference;
    }

    port def PowerOutletPort {
        out item deliveredPower : ElectricalEnergy;
        out item ground : GroundReference;
    }

    port def ControlPort {
        in item command : UserCommand;
        out item status : OutletStatus;
        out item fault : FaultSignal;
    }

    port def SensorPort {
        out item measuredEnergy : ElectricalEnergy;
        out item thermalStatus : ThermalStatus;
        out item fault : FaultSignal;
    }

    action def ReceiveStationPower {
        in item incomingPower : ElectricalEnergy;
        in item incomingGround : GroundReference;
        out item conditionedPower : ElectricalEnergy;
        out item verifiedGround : GroundReference;
    }

    action def ValidateSupply {
        in item measuredPower : ElectricalEnergy;
        in item measuredGround : GroundReference;
        out attribute supplyAcceptable : Boolean;
        out attribute groundAcceptable : Boolean;
    }

    action def ConnectLoad {
        in item conditionedPower : ElectricalEnergy;
        in item verifiedGround : GroundReference;
        out item outletPower : ElectricalEnergy;
        out item outletGround : GroundReference;
    }

    action def DisconnectLoad {
        out item isolatedPower : ElectricalEnergy;
        out attribute loadConnected : Boolean;
    }

    action def DetectElectricalFault {
        in item measuredPower : ElectricalEnergy;
        in item measuredGround : GroundReference;
        in item measuredThermalStatus : ThermalStatus;
        out item detectedFault : FaultSignal;
    }

    action def TripProtection {
        in item detectedFault : FaultSignal;
        out attribute breakerOpen : Boolean;
        out item protectedStatus : OutletStatus;
    }

    action def ResetProtection {
        in item command : UserCommand;
        in item detectedFault : FaultSignal;
        out attribute breakerClosed : Boolean;
        out item resetStatus : OutletStatus;
    }

    action def IndicateStatus {
        in item status : OutletStatus;
        in item fault : FaultSignal;
    }

    state def StationOutletOperatingState {
        entry action initialize {
            out attribute initialized : Boolean = true;
        }

        state Off;
        state Standby;
        state Energized;
        state SupplyingLoad;
        state Faulted;
        state TestMode;
        state MaintenanceIsolated;

        transition first Off;

        transition Off_to_Standby
            first Off
            then Standby;

        transition Standby_to_Energized
            first Standby
            accept after Duration = 1 [true]
            then Energized;

        transition Energized_to_SupplyingLoad
            first Energized
            accept item loadRequest : UserCommand
            if loadRequest.resetRequested == false
            then SupplyingLoad;

        transition SupplyingLoad_to_Faulted
            first SupplyingLoad
            accept item fault : FaultSignal
            if fault.overCurrentDetected or fault.groundFaultDetected or fault.overTemperatureDetected or fault.openGroundDetected
            then Faulted;

        transition Energized_to_Faulted
            first Energized
            accept item fault : FaultSignal
            if fault.overCurrentDetected or fault.groundFaultDetected or fault.overTemperatureDetected or fault.openGroundDetected
            then Faulted;

        transition Faulted_to_Standby
            first Faulted
            accept item command : UserCommand
            if command.resetRequested == true
            then Standby;

        transition Standby_to_TestMode
            first Standby
            accept item command : UserCommand
            if command.testRequested == true
            then TestMode;

        transition TestMode_to_Standby
            first TestMode
            accept after Duration = 5 [true]
            then Standby;

        transition Any_to_MaintenanceIsolated
            first Standby
            accept item isolationCommand : UserCommand
            if isolationCommand.resetRequested == true and isolationCommand.testRequested == true
            then MaintenanceIsolated;
    }

    part def StationPowerFeed {
        port output : PowerInletPort;
        attribute nominalVoltage : Voltage = 120 [V];
        attribute nominalCurrentLimit : Current = 20 [A];
        attribute nominalFrequency : Frequency = 60 [Hz];
        attribute maximumPower : Power = 2400 [W];
        attribute groundResistanceLimit : Resistance = 25 [Ohm];
    }

    part def ProtectiveDevice {
        port lineSide : PowerInletPort;
        port loadSide : PowerOutletPort;
        port diagnostics : SensorPort;
        attribute tripCurrentThreshold : Current = 20 [A];
        attribute groundFaultCurrentThreshold : Current = 0.005 [A];
        attribute tripResponseTime : Duration = 0.025 [s];
        attribute breakerClosed : Boolean;
        perform action detectFault : DetectElectricalFault;
        perform action trip : TripProtection;
        perform action reset : ResetProtection;
    }

    part def ReceptacleInterface {
        port input : PowerInletPort;
        port socket : PowerOutletPort;
        attribute contactResistance : Resistance = 0.05 [Ohm];
        attribute maximumContinuousCurrent : Current = 16 [A];
        attribute tamperResistantShutters : Boolean = true;
        perform action connectLoad : ConnectLoad;
        perform action disconnectLoad : DisconnectLoad;
    }

    part def GroundingPath {
        port sourceGround : PowerInletPort;
        port outletGround : PowerOutletPort;
        attribute bondingResistance : Resistance = 0.1 [Ohm];
        attribute groundContinuityVerified : Boolean;
    }

    part def ThermalMonitor {
        port sensing : SensorPort;
        attribute maximumTerminalTemperature : Temperature = 333.15 [K];
        attribute maximumSurfaceTemperature : Temperature = 323.15 [K];
    }

    part def StatusIndicator {
        port interface : ControlPort;
        attribute powerAvailableLight : Boolean;
        attribute faultLight : Boolean;
        attribute testLight : Boolean;
        perform action indicate : IndicateStatus;
    }

    part def UserResetTestButton {
        port interface : ControlPort;
        attribute resetButtonPressed : Boolean;
        attribute testButtonPressed : Boolean;
    }

    part def StationOutlet {
        port stationSupply : PowerInletPort;
        port userSocket : PowerOutletPort;
        port operatorInterface : ControlPort;

        attribute ratedVoltage : Voltage = 120 [V];
        attribute ratedCurrent : Current = 20 [A];
        attribute ratedFrequency : Frequency = 60 [Hz];
        attribute ratedPower : Power = 2400 [W];
        attribute maximumAllowedSurfaceTemperature : Temperature = 323.15 [K];

        part feed : StationPowerFeed;
        part protection : ProtectiveDevice;
        part receptacle : ReceptacleInterface;
        part groundPath : GroundingPath;
        part thermalMonitor : ThermalMonitor;
        part indicator : StatusIndicator;
        part resetTestButton : UserResetTestButton;

        connection supplyToProtection
            connect stationSupply to protection.lineSide;

        connection protectionToReceptacle
            connect protection.loadSide to receptacle.input;

        connection receptacleToUser
            connect receptacle.socket to userSocket;

        connection stationGroundToGroundPath
            connect stationSupply to groundPath.sourceGround;

        connection groundPathToSocket
            connect groundPath.outletGround to userSocket;

        connection thermalDiagnostics
            connect thermalMonitor.sensing to protection.diagnostics;

        connection indicatorInterface
            connect indicator.interface to operatorInterface;

        connection buttonInterface
            connect resetTestButton.interface to operatorInterface;

        perform action receiveStationPower : ReceiveStationPower;
        perform action validateSupply : ValidateSupply;
        perform action detectElectricalFault : DetectElectricalFault;
        perform action tripProtection : TripProtection;
        perform action resetProtection : ResetProtection;
        exhibit state operatingState : StationOutletOperatingState;
    }

    part outletSystem : StationOutlet {
        attribute ratedVoltage = 120 [V];
        attribute ratedCurrent = 20 [A];
        attribute ratedFrequency = 60 [Hz];
        attribute ratedPower = 2400 [W];
    }

    requirement def PrimaryFunctionRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall receive station electrical power, verify safe supply and grounding conditions, and provide protected electrical power to a connected user load through a receptacle interface. */
        require constraint {
            outlet.ratedVoltage == 120 [V] and
            outlet.ratedFrequency == 60 [Hz] and
            outlet.ratedPower >= 2400 [W]
        }
    }

    requirement def SupplyCompatibilityRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall operate from a nominal single-phase station supply of 120 volts AC at 60 hertz. */
        require constraint {
            outlet.ratedVoltage == 120 [V] and
            outlet.ratedFrequency == 60 [Hz]
        }
    }

    requirement def LoadPowerRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall provide up to 2400 watts of protected electrical power to a connected load without exceeding its rated current. */
        require constraint {
            outlet.ratedPower == outlet.ratedVoltage * outlet.ratedCurrent
        }
    }

    requirement def GroundingRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall maintain a low-resistance grounding path from station ground to the user socket ground contact. */
        require constraint {
            outlet.groundPath.bondingResistance <= 0.1 [Ohm]
        }
    }

    requirement def OverCurrentProtectionRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall interrupt delivered power when measured current exceeds the rated current threshold. */
        require constraint {
            outlet.protection.tripCurrentThreshold <= outlet.ratedCurrent and
            outlet.protection.tripResponseTime <= 0.025 [s]
        }
    }

    requirement def GroundFaultProtectionRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall interrupt delivered power when a ground fault current of 5 milliamperes or greater is detected. */
        require constraint {
            outlet.protection.groundFaultCurrentThreshold <= 0.005 [A]
        }
    }

    requirement def ThermalProtectionRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall detect unsafe heating and prevent continued operation above the allowed surface or terminal temperature limits. */
        require constraint {
            outlet.thermalMonitor.maximumSurfaceTemperature <= outlet.maximumAllowedSurfaceTemperature and
            outlet.thermalMonitor.maximumTerminalTemperature <= 333.15 [K]
        }
    }

    requirement def UserInterfaceRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall provide user-visible indication of power availability, fault condition, and test condition, and shall support reset and test commands. */
        require constraint {
            outlet.indicator.powerAvailableLight == true or
            outlet.indicator.faultLight == true or
            outlet.indicator.testLight == true
        }
    }

    requirement def TamperResistanceRequirement {
        subject outlet : StationOutlet;
        doc /* The Station Outlet shall include tamper-resistant shutters at the receptacle interface to reduce accidental contact with energized conductors. */
        require constraint {
            outlet.receptacle.tamperResistantShutters == true
        }
    }

    satisfy PrimaryFunctionRequirement by outletSystem;
    satisfy SupplyCompatibilityRequirement by outletSystem;
    satisfy LoadPowerRequirement by outletSystem;
    satisfy GroundingRequirement by outletSystem;
    satisfy OverCurrentProtectionRequirement by outletSystem;
    satisfy GroundFaultProtectionRequirement by outletSystem;
    satisfy ThermalProtectionRequirement by outletSystem;
    satisfy UserInterfaceRequirement by outletSystem;
    satisfy TamperResistanceRequirement by outletSystem;
}