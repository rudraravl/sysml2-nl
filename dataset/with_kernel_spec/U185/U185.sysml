package CerebralShuntModel {
    private import ScalarValues::*;
    private import ISQ::*;

    item def CSF;

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;

    port def CSFInPort {
        in csf : CSF;
        attribute pressure : PressureValue;
    }

    port def CSFOutPort {
        out csf : CSF;
        attribute pressure : PressureValue;
    }

    part def BrainVentricle {
        attribute intracranialPressure : PressureValue;
        port csfOutPort : CSFOutPort;
    }

    part def DrainageSite {
        port csfInPort : CSFInPort;
    }

    part def VentricularCatheter {
        port csfInPort : CSFInPort;
        port csfOutPort : CSFOutPort;
    }

    part def CSFReservoir {
        port csfInPort : CSFInPort;
        port csfOutPort : CSFOutPort;
        attribute capacity : VolumeValue;
    }

    part def PressureRegulatingValve {
        attribute openingPressure : PressureValue;
        attribute closingPressure : PressureValue;
        port csfInPort : CSFInPort;
        port csfOutPort : CSFOutPort;
        exhibit state valveOperation;
    }

    part def DistalCatheter {
        port csfInPort : CSFInPort;
        port csfOutPort : CSFOutPort;
    }

    part def CerebralShunt {
        attribute patientICP : PressureValue;
        attribute safePressureThreshold : PressureValue;
        exhibit state shuntOperation;
    }

    state def ShuntOperation;
    state def ValveOperation;

    action def MonitorPressure;
    action def OpenValveAction;
    action def CloseValveAction;
    action def DrainFluidAction;

    attribute def PressureHigh;
    attribute def PressureSafe;
    attribute def ObstructionDetected;
    attribute def ObstructionCleared;

    requirement def PressureControlRequirement {
        subject shunt : CerebralShunt;
        attribute maxThreshold : PressureValue;
        require constraint {
            shunt.patientICP <= maxThreshold
        }
    }

    requirement def ValveSafetyRequirement {
        subject valve : PressureRegulatingValve;
        require constraint {
            valve.openingPressure > valve.closingPressure
        }
    }

    requirement def DrainageContinuityRequirement {
        subject shunt : CerebralShunt;
        require constraint {
            shunt.patientICP >= 0
        }
    }

    part patientContext {
        part ventricle : BrainVentricle;

        part peritonealCavity : DrainageSite;

        part shunt : CerebralShunt {
            part ventricularCatheter : VentricularCatheter;

            part reservoir : CSFReservoir;

            part valve : PressureRegulatingValve {
                exhibit state valveOperation : ValveOperation {
                    entry; then closed;
                    state closed;
                    accept when csfInPort.pressure > openingPressure
                        do action openValve : OpenValveAction
                        then open;
                    state open {
                        do action drain : DrainFluidAction;
                    }
                    accept when csfInPort.pressure <= closingPressure
                        do action closeValve : CloseValveAction
                        then closed;
                }
            }

            part distalCatheter : DistalCatheter;

            flow csfFlow1 of CSF
                from ventricularCatheter.csfOutPort.csf to reservoir.csfInPort.csf;
            flow csfFlow2 of CSF
                from reservoir.csfOutPort.csf to valve.csfInPort.csf;
            flow csfFlow3 of CSF
                from valve.csfOutPort.csf to distalCatheter.csfInPort.csf;

            exhibit state shuntOperation : ShuntOperation {
                entry; then normal;
                state normal {
                    do action monitor : MonitorPressure;
                }
                accept PressureHigh
                    do action openValve : OpenValveAction
                    then draining;
                state draining {
                    do action drain : DrainFluidAction;
                }
                accept PressureSafe
                    do action closeValve : CloseValveAction
                    then normal;
                accept ObstructionDetected
                    then blocked;
                state blocked;
                accept ObstructionCleared
                    then normal;
            }
        }

        flow csfFlowIn of CSF
            from ventricle.csfOutPort.csf to shunt.ventricularCatheter.csfInPort.csf;
        flow csfFlowOut of CSF
            from shunt.distalCatheter.csfOutPort.csf to peritonealCavity.csfInPort.csf;
    }

    requirement pressureControl : PressureControlRequirement;
    requirement valveSafety : ValveSafetyRequirement;
    requirement drainageContinuity : DrainageContinuityRequirement;
}
