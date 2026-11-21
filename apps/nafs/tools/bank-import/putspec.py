def parse(spec,total):
    M={}
    for line in spec.strip().split('\n'):
        r,v=line.split('=') if '=' in line else line.split(':',1)
        a,b=map(int,r.split('-'))
        vals=[]
        for x in v.split(','):
            x=x.strip(); vals.append(int(x) if x.lstrip('-').isdigit() else x)
        assert b-a+1==len(vals),line
        for q,k in zip(range(a,b+1),vals): M[q]=k
    assert len(M)==total,(len(M),total)
    return M
