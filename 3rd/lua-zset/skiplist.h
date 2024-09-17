//
#include <stdlib.h>

#define SKIPLIST_MAXLEVEL 32
#define SKIPLIST_P 0.25

typedef struct slobj {
    char *ptr;
    size_t length;
} slobj;

typedef struct skiplistNode {
    slobj* obj;
    double score;
    struct skiplistNode *backward;
    struct skiplistLevel {
        struct skiplistNode *forward;
        unsigned int span;
    }level[];
} skiplistNode;

typedef struct skiplist {
    struct skiplistNode *header, *tail;
    unsigned long length;
    int level;
} skiplist;

typedef void (*slDeleteCb) (void *ud, slobj *obj);
slobj* slCreateObj(const char* ptr, size_t length);
void slFreeObj(slobj *obj);

skiplist *slCreate(void);
void slFree(skiplist *sl);
void slDump(skiplist *sl);

void slInsert(skiplist *sl, double score, slobj *obj);
int slDelete(skiplist *sl, double score, slobj *obj);
unsigned long slDeleteByRank(skiplist *sl, unsigned int start, unsigned int end, slDeleteCb cb, void* ud);

unsigned long slGetRank(skiplist *sl, double score, slobj *o);
skiplistNode* slGetNodeByRank(skiplist *sl, unsigned long rank);

skiplistNode *slFirstInRange(skiplist *sl, double min, double max);
skiplistNode *slLastInRange(skiplist *sl, double min, double max);

