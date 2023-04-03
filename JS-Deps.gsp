// JS-Deps: Node Package Manager Dependency Graph
//
// Nodes are packages. Edges are directed from a package to its dependencies.

#pragma gs attribute(float X[N])
#pragma gs attribute(float Y[N])
#pragma gs attribute(uint Date[N])
#pragma gs attribute(uint Devs[N])
#pragma gs attribute(uint Vuln[N])

#define NOV_09_2010 1289278800
#define MAR_22_2016 1458619200

#define JAN_01_2011 1293858000
#define JAN_01_2012 1325394000
#define JAN_01_2013 1357016400
#define JAN_01_2014 1388552400
#define JAN_01_2015 1420088400
#define JAN_01_2016 1451624400

// Some controls
#pragma gs define(USE_COLOR)
#pragma gs define(USE_FILTER)
#pragma gs define(USE_RELATIONAL)


#pragma gs shader(positional)
void main() {
    float x = X[gs_NodeIndex];
    float y = Y[gs_NodeIndex];

    gs_NodePosition = vec3(x, y, 0);
}


#pragma gs shader(relational)
void main() {
    #pragma gs scratch(uint in_degree[N])
    #pragma gs scratch(uint out_degree[N])
    #pragma gs scratch(atomic_uint in_degree_max)
    #pragma gs scratch(atomic_uint out_degree_max)

    #pragma gs define(USE_RELATIONAL 1)
    #if USE_RELATIONAL
    uint od = 1 + atomicAdd(out_degree[gs_SourceIndex], 1);
    atomicCounterMax(out_degree_max, od);

    uint id = 1 + atomicAdd(in_degree[gs_TargetIndex], 1);
    atomicCounterMax(in_degree_max, id);
    #endif /* USE_RELATIONAL */
}


#pragma gs shader(appearance)
void main() {
    #pragma gs scratch(uint Seen[E])
    bool first = 0 == atomicAdd(Seen[gs_EdgeIndex], 1);
    bool d = false;

    #pragma gs scratch(atomic_uint total)
    if (first) atomicCounterAdd(total, 1);

    #pragma gs define(FILTER_BY_DATE 1)
    #if FILTER_BY_DATE
    #pragma gs define(LO JAN_01_2014)
    #pragma gs define(HI JAN_01_2015)

    if (Date[gs_SourceIndex] < LO) {
        d = true;
        #pragma gs scratch(atomic_uint source_date_too_lo)
        if (first) atomicCounterAdd(source_date_too_lo, 1);
    }

    if (Date[gs_SourceIndex] > HI) {
        d = true;
        #pragma gs scratch(atomic_uint source_date_too_hi)
        if (first) atomicCounterAdd(source_date_too_hi, 1);
    }

    if (Date[gs_TargetIndex] < LO) {
        d = true;
        #pragma gs scratch(atomic_uint target_date_too_lo)
        if (first) atomicCounterAdd(target_date_too_lo, 1);
    }

    if (Date[gs_TargetIndex] > HI) {
        d = true;
        #pragma gs scratch(atomic_uint target_date_too_hi)
        if (first) atomicCounterAdd(target_date_too_hi, 1);
    }
    #endif /* FILTER_BY_DATE */

    if (d) {
        #pragma gs scratch(atomic_uint discarded)
        if (first) atomicCounterAdd(discarded, 1);
        discard;
    } else {
        #pragma gs scratch(atomic_uint kept)
        if (first) atomicCounterAdd(kept, 1);
    }

    bool vuln = bool(Vuln[gs_SourceIndex]) || bool(Vuln[gs_TargetIndex]);
    bool risky = Devs[gs_SourceIndex] > Devs[gs_TargetIndex];

    #if USE_RELATIONAL
    const uint depends_on_source = in_degree[gs_SourceIndex];
    const uint depends_on_target = in_degree[gs_TargetIndex];

    risky = depends_on_source + depends_on_target > 100 * Devs[gs_TargetIndex];
    #endif /* USE_RELATIONAL */

    if (risky) {
        #pragma gs scratch(atomic_uint total_risky)
        if (first) atomicCounterAdd(total_risky, 1);
    }

    if (risky && vuln) {
        #pragma gs scratch(atomic_uint total_vuln_and_risky)
        if (first) atomicCounterAdd(total_vuln_and_risky, 1);
    }

    if (vuln) {
        #pragma gs scratch(atomic_uint total_vuln)
        if (first) atomicCounterAdd(total_vuln, 1);
    }

    gs_FragColor = vec4(0.1);
    gs_FragColor.r = float(vuln);
    gs_FragColor.b = float(risky);
}
