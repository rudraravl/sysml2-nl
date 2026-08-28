package ThorpeTubeFlowmeter {
    private import ScalarValues::*;
    private import ISQ::*;

    item def Gas;
    item def Oxygen :> Gas;

    value def FlowRate :> Real;
    value def Height :> Real;
    value def ForceValue :> Real;

    port def GasInletPort { 
        in item gas : Gas; 
    }
    port def GasOutletPort { 
        out item gas : Gas; 
    }

    requirement def VerticalOrientationRequirement {
        doc /* The flowmeter must be mounted and used in a strictly vertical, upright orientation to ensure accurate float positioning and flow measurement. */
    }
    
    requirement def MaxFlowRequirement {
        doc /* The device shall indicate an overrange condition when the gas flow rate exceeds the maximum calibrated measurement capability. */
        attribute maxFlow : FlowRate = 15.0;
    }

    part def Float {
        attribute weight : ForceValue;
        attribute dragForce : ForceValue;
        attribute position : Height;
    }

    part def TaperedGlassTube {
        attribute bottomDiameter : Height;
        attribute topDiameter : Height;
        attribute tubeLength : Height;
        part float : Float;
    }

    part def Housing {
        attribute isVertical : Boolean = true;
    }

    part def Scale {
        attribute maxFlow : FlowRate = 15.0;
        attribute graduationMarks : Height[*];
    }

    part def FlowControlValve {
        attribute flowRate : FlowRate;
        action adjustFlow {
            in targetFlow : FlowRate;
        }
    }

    action def MeasureFlow {
        in floatPosition : Height;
        out flowRate : FlowRate;
    }

    part def ThorpeTubeFlowmeter {
        port inlet : GasInletPort;
        port outlet : GasOutletPort;
        
        part housing : Housing;
        part scale : Scale;
        part valve : FlowControlValve {
            in item gasIn : Gas = inlet.gas;
            out item gasOut : Gas;
        }
        part tube : TaperedGlassTube {
            in item gasIn : Gas = valve.gasOut;
            out item gasOut : Gas = outlet.gas;
        }

        perform action measureFlow : MeasureFlow;

        state flowmeterStates {
            entry; then NoFlow;

            state NoFlow;

            transition NoFlow_to_Rising
                first NoFlow
                accept when valve.flowRate > 0.0
                then Rising;

            state Rising;

            transition Rising_to_SteadyState
                first Rising
                accept when tube.float.dragForce == tube.float.weight
                then SteadyState;

            state SteadyState {
                do measureFlow;
            }

            transition SteadyState_to_Rising
                first SteadyState
                accept when valve.flowRate != 0.0
                then Rising;

            transition SteadyState_to_Overrange
                first SteadyState
                accept when valve.flowRate > scale.maxFlow
                then Overrange;

            transition Rising_to_Overrange
                first Rising
                accept when valve.flowRate > scale.maxFlow
                then Overrange;

            state Overrange;

            transition Overrange_to_Rising
                first Overrange
                accept when valve.flowRate <= scale.maxFlow
                then Rising;

            transition SteadyState_to_NoFlow
                first SteadyState
                accept when valve.flowRate == 0.0
                then NoFlow;

            transition Overrange_to_NoFlow
                first Overrange
                accept when valve.flowRate == 0.0
                then NoFlow;
        }
        
        satisfy VerticalOrientationRequirement by housing;
        satisfy MaxFlowRequirement by scale;
    }
}
