/* Shared data access for the EGS Quizit question draw arena. */
(() => {
  'use strict';

  const config = window.EGS_QUIZIT_SUPABASE || {};
  const enabled = Boolean(config.url && config.publishableKey && window.supabase?.createClient);
  const client = enabled ? window.supabase.createClient(config.url, config.publishableKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  }) : null;
  let currentUser = null;
  let admin = false;
  let channel = null;

  const fail = (error) => { if (error) throw new Error(error.message || 'Supabase request failed.'); };
  const adminRequired = () => { if (!admin) throw new Error('Sign in with the quiz admin account to make changes.'); };
  const questionFromRow = (row) => ({
    id: row.id, round: row.round, difficulty: row.difficulty, tag: row.tag,
    tagKey: row.tag_key, question: row.question, answer: '', mediaUrl: row.media_url || '',
    source: row.source || '', createdAt: row.created_at
  });
  const drawFromRow = (row) => ({
    id: row.id, round: row.round, tag: row.tag, tagKey: row.tag_key,
    questionId: row.question_id, difficulty: row.difficulty, method: row.method,
    time: row.time, active: row.active, resetAt: row.reset_at
  });
  const questionToRow = (q) => ({
    id: q.id, round: q.round, difficulty: q.difficulty || 'foundation', tag: q.tag,
    tag_key: q.tagKey, question: q.question, media_url: q.mediaUrl || '', source: q.source || ''
  });

  async function attachAnswers(questions) {
    if (!admin || !questions.length) return questions;
    const answers = new Map();
    for (let i = 0; i < questions.length; i += 200) {
      const ids = questions.slice(i, i + 200).map((q) => q.id);
      const { data, error } = await client.from('quizit_question_answers').select('question_id,answer').in('question_id', ids);
      fail(error);
      for (const row of data || []) answers.set(row.question_id, row.answer || '');
    }
    return questions.map((q) => ({ ...q, answer: answers.get(q.id) || '' }));
  }

  async function getQuestions(round) {
    const rows = [];
    for (let from = 0; ; from += 1000) {
      const { data, error } = await client.from('quizit_questions').select('*').eq('round', round).order('tag').range(from, from + 999);
      fail(error);
      rows.push(...(data || []));
      if (!data || data.length < 1000) break;
    }
    return attachAnswers(rows.map(questionFromRow));
  }

  async function getAllQuestions() {
    const all = [];
    for (const round of ['Science', 'Sports', 'General Knowledge', 'History', 'Current Affairs', 'Music']) {
      all.push(...await getQuestions(round));
    }
    return all;
  }

  async function getQuestion(round, tagKey) {
    const { data, error } = await client.from('quizit_questions').select('*').eq('round', round).eq('tag_key', tagKey).maybeSingle();
    fail(error);
    if (!data) return null;
    const q = questionFromRow(data);
    if (admin) {
      const { data: answer, error: answerError } = await client.from('quizit_question_answers').select('answer').eq('question_id', q.id).maybeSingle();
      fail(answerError);
      q.answer = answer?.answer || '';
    }
    return q;
  }

  async function countQuestions(round) {
    const { count, error } = await client.from('quizit_questions').select('id', { count: 'exact', head: true }).eq('round', round);
    fail(error);
    return count || 0;
  }

  async function countAllQuestions() {
    const counts = await Promise.all(['Science', 'Sports', 'General Knowledge', 'History', 'Current Affairs', 'Music'].map(countQuestions));
    return counts.reduce((sum, n) => sum + n, 0);
  }

  async function insertQuestions(items, ignoreDuplicates = false) {
    adminRequired();
    for (let i = 0; i < items.length; i += 400) {
      const batch = items.slice(i, i + 400);
      const rows = batch.map(questionToRow);
      const request = ignoreDuplicates
        ? client.from('quizit_questions').upsert(rows, { onConflict: 'round,tag_key', ignoreDuplicates: true })
        : client.from('quizit_questions').insert(rows);
      const { error } = await request;
      fail(error);
      const answerRows = batch.map((q) => ({ question_id: q.id, answer: q.answer || '' }));
      if (answerRows.length) {
        const { error: answerError } = await client.from('quizit_question_answers').upsert(answerRows, { onConflict: 'question_id' });
        fail(answerError);
      }
    }
  }

  async function updateQuestion(question) {
    adminRequired();
    const { data, error } = await client.from('quizit_questions')
      .update(questionToRow(question)).eq('id', question.id).select('id').maybeSingle();
    fail(error);
    if (!data) throw new Error('The question was not updated. Check administrator access and try again.');
    const { error: answerError } = await client.from('quizit_question_answers')
      .upsert({ question_id: question.id, answer: question.answer || '' }, { onConflict: 'question_id' });
    fail(answerError);
  }

  async function deleteQuestion(id) {
    adminRequired();
    const { data: priorDraw, error: drawError } = await client.from('quizit_draws').select('id').eq('question_id', id).limit(1);
    fail(drawError);
    if (priorDraw?.length) throw new Error('This question is in the draw history, so it is kept for the audit trail.');
    const { error } = await client.from('quizit_questions').delete().eq('id', id);
    fail(error);
  }

  async function getDraws(round) {
    const rows = [];
    for (let from = 0; ; from += 1000) {
      const { data, error } = await client.from('quizit_draws').select('*').eq('round', round).order('time', { ascending: false }).range(from, from + 999);
      fail(error);
      rows.push(...(data || []));
      if (!data || data.length < 1000) break;
    }
    return rows.map(drawFromRow);
  }

  async function getAllDraws() {
    const rows = [];
    for (let from = 0; ; from += 1000) {
      const { data, error } = await client.from('quizit_draws').select('*').order('time', { ascending: false }).range(from, from + 999);
      fail(error);
      rows.push(...(data || []));
      if (!data || data.length < 1000) break;
    }
    return rows.map(drawFromRow);
  }

  async function addDraw(q, method) {
    adminRequired();
    const draw = {
      id: crypto.randomUUID(), round: q.round, tag: q.tag, tag_key: q.tagKey,
      question_id: q.id, difficulty: q.difficulty || 'foundation', method,
      time: new Date().toISOString(), active: true
    };
    const { data, error } = await client.from('quizit_draws').insert(draw).select('*').single();
    if (error?.code === '23505') {
      const { data: found, error: findError } = await client.from('quizit_draws').select('*').eq('round', q.round).eq('tag_key', q.tagKey).eq('active', true).single();
      fail(findError);
      return { existing: true, draw: drawFromRow(found) };
    }
    fail(error);
    return { existing: false, draw: drawFromRow(data) };
  }

  async function resetDraws(round) {
    adminRequired();
    const { error } = await client.from('quizit_draws').update({ active: false, reset_at: new Date().toISOString() }).eq('round', round).eq('active', true);
    fail(error);
  }

  async function readState() {
    const { data, error } = await client.from('quizit_live_state').select('state,updated_at').eq('id', 'main').single();
    fail(error);
    return data;
  }

  async function writeState(state) {
    adminRequired();
    const prior = await readState();
    const next = { ...(prior?.state || {}), ...state };
    if (!Object.prototype.hasOwnProperty.call(state, 'activeQuestion')) next.activeQuestion = prior?.state?.activeQuestion ?? null;
    const { error } = await client.from('quizit_live_state').upsert({ id: 'main', state: next, updated_at: new Date().toISOString() });
    fail(error);
  }

  async function publishQuestion(question) {
    adminRequired();
    const prior = await readState();
    const state = { ...(prior?.state || {}), activeQuestion: question || null };
    const { error } = await client.from('quizit_live_state').upsert({ id: 'main', state, updated_at: new Date().toISOString() });
    fail(error);
  }

  async function start(onState, onData, onAuth, onQuestion) {
    if (!enabled) return { enabled: false, state: null };
    const { data, error } = await client.auth.getSession();
    fail(error);
    setAuth(data.session?.user || null, onAuth);
    client.auth.onAuthStateChange((_event, session) => {
      setAuth(session?.user || null, onAuth);
    });
    const state = await readState();
    if (state.state?.activeQuestion) onQuestion?.(state.state.activeQuestion);
    channel = client.channel('quizit-shared-arena')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'quizit_live_state' }, (payload) => {
        if (payload.new?.state) {
          onState?.(payload.new.state);
          onQuestion?.(payload.new.state.activeQuestion || null);
        }
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'quizit_questions' }, () => onData?.('questions'))
      .on('postgres_changes', { event: '*', schema: 'public', table: 'quizit_draws' }, () => onData?.('draws'))
      .subscribe();
    return { enabled: true, state: state.state, updatedAt: state.updated_at };
  }

  function setAuth(nextUser, notify) {
    currentUser = nextUser;
    admin = Boolean(currentUser?.app_metadata?.role === 'admin');
    notify?.({ user: currentUser, admin });
  }

  async function signIn(email, password) {
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    fail(error);
    setAuth(data.user, window.quizitAuthChanged);
    if (!admin) {
      await client.auth.signOut();
      setAuth(null, window.quizitAuthChanged);
      throw new Error('This account is not marked as a quiz administrator. Ask the project owner to grant it admin access.');
    }
    return data.user;
  }

  async function signOut() {
    if (!enabled) return;
    const { error } = await client.auth.signOut();
    fail(error);
    setAuth(null, window.quizitAuthChanged);
  }

  window.QuizitCloud = {
    enabled, start, signIn, signOut, isAdmin: () => admin,
    getQuestions, getAllQuestions, getQuestion, countQuestions, countAllQuestions, insertQuestions, updateQuestion, deleteQuestion,
    getDraws, getAllDraws, addDraw, resetDraws, readState, writeState,
    publishQuestion,
    get user() { return currentUser; }
  };
})();
